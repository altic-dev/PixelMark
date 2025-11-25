import Foundation
import Cocoa
import AVFoundation

/// Manages the creation, loading, and saving of PixelMark projects
class ProjectManager {
    static let shared = ProjectManager()
    
    private init() {}
    
    /// Creates a new .pixelmark project bundle from a recorded file
    func createProject(from sourceURL: URL, metadata: ProjectMetadata, in directory: URL) throws -> Project {
        // Generate filenames
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let projectName = "PixelMark-\(timestamp)"
        let bundleName = "\(projectName).\(Project.fileExtension)"
        
        // Create bundle directory
        let bundleURL = directory.appendingPathComponent(bundleName)
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        
        // Create media directory
        let mediaDirURL = bundleURL.appendingPathComponent("media")
        try FileManager.default.createDirectory(at: mediaDirURL, withIntermediateDirectories: true)
        
        // Move recording to media directory
        let recordingDestURL = mediaDirURL.appendingPathComponent("recording.mp4")
        if FileManager.default.fileExists(atPath: recordingDestURL.path) {
            try FileManager.default.removeItem(at: recordingDestURL)
        }
        try FileManager.default.moveItem(at: sourceURL, to: recordingDestURL)
        
        // Create project struct
        let project = Project.createNew(
            name: projectName,
            recordingFileName: "media/recording.mp4",
            metadata: metadata
        )
        
        // Save project.json
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .prettyPrinted
        jsonEncoder.dateEncodingStrategy = .iso8601
        let jsonData = try jsonEncoder.encode(project)
        
        let jsonPath = bundleURL.appendingPathComponent("project.json")
        try jsonData.write(to: jsonPath)
        
        // Generate thumbnail
        if let thumbnail = generateThumbnail(for: recordingDestURL) {
            let thumbDirURL = bundleURL.appendingPathComponent("thumbnails")
            try FileManager.default.createDirectory(at: thumbDirURL, withIntermediateDirectories: true)
            let thumbURL = thumbDirURL.appendingPathComponent("preview.jpg")
            if let data = thumbnail.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: data),
               let jpgData = bitmap.representation(using: .jpeg, properties: [:]) {
                try jpgData.write(to: thumbURL)
            }
        }
        
        return project
    }
    
    /// Loads a project from a .pixelmark bundle
    func loadProject(at url: URL) throws -> Project {
        let jsonPath = url.appendingPathComponent("project.json")
        let data = try Data(contentsOf: jsonPath)
        
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
        var project = try jsonDecoder.decode(Project.self, from: data)
        
        // If duration is 0, try to fetch it from the video file
        if project.duration == 0 {
            let recordingPath = url.appendingPathComponent(project.recordingFileName)
            let asset = AVAsset(url: recordingPath)
            project.duration = CMTimeGetSeconds(asset.duration)
        }
        
        return project
    }
    
    private func generateThumbnail(for url: URL) -> NSImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        } catch {
            print("Failed to generate thumbnail: \(error)")
            return nil
        }
    }
}
