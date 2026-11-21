import Foundation
import os

/*
This file's only job is: keep the player's session videos. A new video goes to the player's own iCloud when it's on,
or stays on this phone when it's off. As the app opens, videos already safe in iCloud are removed from the phone; one
comes back to the phone when the player wants to watch it. Only Cheddar on the player's own devices can open them.
*/
enum SavedVideos {
    static let folder = URL.applicationSupportDirectory.appending(path: "Videos", directoryHint: .isDirectory)
    private static let container = "iCloud.com.viqas.Cheddar"
    private static let cloudFolder = OSAllocatedUnfairLock<URL?>(initialState: nil)  // nil until found, or iCloud is off

    // Looks for the player's iCloud once as the app opens. The lookup can be slow, so it's kept off the main thread.
    static func findCloud() async {
        await Task.detached {
            guard let root = FileManager.default.url(forUbiquityContainerIdentifier: container) else { return }
            let videos = root.appending(path: "Videos", directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: videos, withIntermediateDirectories: true)
            cloudFolder.withLock { $0 = videos }
            freeSpace(in: videos)
        }.value
    }

    // Puts a new video in the player's iCloud when it's on, otherwise in this phone's folder. It's slow, so it's never
    // called on the main thread.
    static func keep(_ file: URL, as name: String) throws {
        if let cloud = cloudFolder.withLock({ $0 }) {
            try FileManager.default.setUbiquitous(true, itemAt: file, destinationURL: cloud.appending(path: name))
        } else {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: file, to: folder.appending(path: name))
        }
    }

    // The saved video with that file name, on this phone or in iCloud, or nil when it isn't saved.
    static func url(_ name: String) -> URL? {
        let local = folder.appending(path: name)
        if exists(local) { return local }
        guard let cloud = cloudFolder.withLock({ $0 })?.appending(path: name) else { return nil }
        let standIn = cloud.deletingLastPathComponent().appending(path: ".\(name).icloud")  // left when it's off the phone
        return exists(cloud) || exists(standIn) ? cloud : nil
    }

    // True when the video can play right now: it's kept on this phone, or it's an iCloud video that's downloaded.
    static func isOnPhone(_ url: URL) -> Bool {
        var fresh = url
        fresh.removeAllCachedResourceValues()
        guard let values = try? fresh.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey])
        else { return false }
        return values.isUbiquitousItem != true || values.ubiquitousItemDownloadingStatus == .current
    }

    // Brings an iCloud video back to the phone so it can play. Gives up after a minute.
    static func download(_ url: URL) async {
        guard !isOnPhone(url) else { return }
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        for _ in 0..<120 {
            if isOnPhone(url) { return }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    // Deletes a saved video from this phone, or from the player's iCloud and every device it's on.
    static func delete(_ name: String) {
        guard let url = url(name) else { return }
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: nil) { spot in
            try? FileManager.default.removeItem(at: spot)
        }
    }

    // Removes the phone's copy of each video that's safely in iCloud; it downloads again when watched.
    private static func freeSpace(in videos: URL) {
        let keys: Set<URLResourceKey> = [.ubiquitousItemIsUploadedKey, .ubiquitousItemDownloadingStatusKey]
        let files = (try? FileManager.default.contentsOfDirectory(at: videos, includingPropertiesForKeys: Array(keys))) ?? []
        for file in files {
            guard let values = try? file.resourceValues(forKeys: keys), values.ubiquitousItemIsUploaded == true,
                  values.ubiquitousItemDownloadingStatus == .current else { continue }
            try? FileManager.default.evictUbiquitousItem(at: file)
        }
    }

    private static func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }
}
