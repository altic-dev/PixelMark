import Foundation

/// Represents a PixelMark project package
struct Project: Codable, Identifiable {
    let id: UUID
    var name: String
    let createdAt: Date
    var duration: TimeInterval
    
    /// Relative path to the recording file inside the bundle (e.g., "recording.mp4")
    let recordingFileName: String
    
    /// Metadata about the recording environment
    var metadata: ProjectMetadata
    
    /// The uniform type identifier for PixelMark projects
    static let fileExtension = "pixelmark"
    
    static func createNew(name: String, recordingFileName: String, metadata: ProjectMetadata) -> Project {
        return Project(
            id: UUID(),
            name: name,
            createdAt: Date(),
            duration: 0, // To be updated
            recordingFileName: recordingFileName,
            metadata: metadata
        )
    }
}

struct ProjectMetadata: Codable {
    /// The type of source recorded (screen, window, etc.)
    var sourceType: String
    
    /// Name of the window recorded, if any
    var windowTitle: String?
    
    /// App name of the window recorded, if any
    var appName: String?
    
    /// Display ID recorded, if any
    var displayID: UInt32?
    
    /// Recording resolution (width x height)
    var recordingWidth: Int?
    var recordingHeight: Int?
    
    /// Recorded events (cursor, clicks, keyboard, scroll)
    var events: [RecordingEvent] = []
}

// MARK: - Recording Events

/// Represents a single event during recording
struct RecordingEvent: Codable {
    let timestamp: TimeInterval
    let type: EventType
    let data: EventData
}

/// Types of events that can be recorded
enum EventType: String, Codable {
    case cursorMove
    case mouseClick
    case mouseDown
    case mouseUp
    case scroll
    case keyPress
}

/// Data associated with each event type
enum EventData: Codable {
    case cursor(x: CGFloat, y: CGFloat)
    case click(x: CGFloat, y: CGFloat, button: MouseButton)
    case scroll(deltaX: CGFloat, deltaY: CGFloat)
    case key(keyCode: UInt16, characters: String?, modifiers: [String])
    
    enum CodingKeys: String, CodingKey {
        case type, x, y, button, deltaX, deltaY, keyCode, characters, modifiers
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "cursor":
            let x = try container.decode(CGFloat.self, forKey: .x)
            let y = try container.decode(CGFloat.self, forKey: .y)
            self = .cursor(x: x, y: y)
        case "click":
            let x = try container.decode(CGFloat.self, forKey: .x)
            let y = try container.decode(CGFloat.self, forKey: .y)
            let button = try container.decode(MouseButton.self, forKey: .button)
            self = .click(x: x, y: y, button: button)
        case "scroll":
            let deltaX = try container.decode(CGFloat.self, forKey: .deltaX)
            let deltaY = try container.decode(CGFloat.self, forKey: .deltaY)
            self = .scroll(deltaX: deltaX, deltaY: deltaY)
        case "key":
            let keyCode = try container.decode(UInt16.self, forKey: .keyCode)
            let characters = try container.decodeIfPresent(String.self, forKey: .characters)
            let modifiers = try container.decode([String].self, forKey: .modifiers)
            self = .key(keyCode: keyCode, characters: characters, modifiers: modifiers)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown event data type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .cursor(let x, let y):
            try container.encode("cursor", forKey: .type)
            try container.encode(x, forKey: .x)
            try container.encode(y, forKey: .y)
        case .click(let x, let y, let button):
            try container.encode("click", forKey: .type)
            try container.encode(x, forKey: .x)
            try container.encode(y, forKey: .y)
            try container.encode(button, forKey: .button)
        case .scroll(let deltaX, let deltaY):
            try container.encode("scroll", forKey: .type)
            try container.encode(deltaX, forKey: .deltaX)
            try container.encode(deltaY, forKey: .deltaY)
        case .key(let keyCode, let characters, let modifiers):
            try container.encode("key", forKey: .type)
            try container.encode(keyCode, forKey: .keyCode)
            try container.encodeIfPresent(characters, forKey: .characters)
            try container.encode(modifiers, forKey: .modifiers)
        }
    }
}

/// Mouse button types
enum MouseButton: String, Codable {
    case left
    case right
    case middle
}
