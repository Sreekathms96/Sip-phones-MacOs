import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum DatabaseError: LocalizedError {
    case openFailed(String)
    case executionFailed(String)
    case prepareFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let message), .executionFailed(let message), .prepareFailed(let message):
            return message
        }
    }
}

final class DatabaseManager: @unchecked Sendable {
    static let shared = DatabaseManager()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.sipphones.softphone.database")

    private init() {}

    deinit {
        if db != nil { sqlite3_close(db) }
    }

    func open() throws {
        try queue.sync {
            guard db == nil else { return }
            let supportURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("sip-phones", isDirectory: true)
            try FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
            let dbURL = supportURL.appendingPathComponent("CallHistory.sqlite")

            guard sqlite3_open(dbURL.path, &db) == SQLITE_OK else {
                throw DatabaseError.openFailed(lastError)
            }
            try execute("""
            CREATE TABLE IF NOT EXISTS call_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                remote_uri TEXT NOT NULL,
                display_name TEXT NOT NULL,
                direction TEXT NOT NULL,
                duration REAL NOT NULL,
                timestamp REAL NOT NULL
            );
            """)
            try execute("CREATE INDEX IF NOT EXISTS idx_call_history_timestamp ON call_history(timestamp DESC);")
        }
    }

    func insertHistory(remoteURI: String, displayName: String, direction: CallDirection, duration: TimeInterval, timestamp: Date) throws {
        try queue.sync {
            let sql = "INSERT INTO call_history(remote_uri, display_name, direction, duration, timestamp) VALUES (?, ?, ?, ?, ?);"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(lastError)
            }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, remoteURI, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, displayName, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 3, direction.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(statement, 4, duration)
            sqlite3_bind_double(statement, 5, timestamp.timeIntervalSince1970)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.executionFailed(lastError)
            }
        }
    }

    func loadHistory(limit: Int = 200) throws -> [CallHistoryEntry] {
        try queue.sync {
            let sql = "SELECT id, remote_uri, display_name, direction, duration, timestamp FROM call_history ORDER BY timestamp DESC LIMIT ?;"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(lastError)
            }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int(statement, 1, Int32(limit))

            var entries: [CallHistoryEntry] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                let directionRaw = String(cString: sqlite3_column_text(statement, 3))
                guard let direction = CallDirection(rawValue: directionRaw) else { continue }
                entries.append(CallHistoryEntry(
                    id: sqlite3_column_int64(statement, 0),
                    remoteURI: String(cString: sqlite3_column_text(statement, 1)),
                    displayName: String(cString: sqlite3_column_text(statement, 2)),
                    direction: direction,
                    duration: sqlite3_column_double(statement, 4),
                    timestamp: Date(timeIntervalSince1970: sqlite3_column_double(statement, 5))
                ))
            }
            return entries
        }
    }

    private func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &errorMessage) != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? lastError
            sqlite3_free(errorMessage)
            throw DatabaseError.executionFailed(message)
        }
    }

    private var lastError: String {
        guard let db else { return "Database is not open." }
        return String(cString: sqlite3_errmsg(db))
    }
}
