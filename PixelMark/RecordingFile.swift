//
//  RecordingFile.swift
//  PixelMark
//
//  Created by PixelMark on 11/23/25.
//

import Foundation

struct RecordingFile: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let creationDate: Date
    let fileSize: Int64
    
    /// The project metadata if this is a .pixelmark bundle
    var project: Project?
    
    /// The URL to the actual video media
    var mediaURL: URL {
        if let project = project {
            return url.appendingPathComponent(project.recordingFileName)
        }
        return url
    }
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: creationDate)
    }
    
    /// Initialize from a legacy MP4 file
    init(url: URL, name: String, creationDate: Date, fileSize: Int64) {
        self.url = url
        self.name = name
        self.creationDate = creationDate
        self.fileSize = fileSize
        self.project = nil
    }
    
    /// Initialize from a PixelMark project bundle
    init?(projectURL: URL) {
        guard let project = try? ProjectManager.shared.loadProject(at: projectURL) else {
            return nil
        }
        
        // Get bundle size
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: projectURL.path)[.size] as? Int64) ?? 0
        
        self.url = projectURL
        self.name = project.name
        self.creationDate = project.createdAt
        self.fileSize = fileSize
        self.project = project
    }
}
