import Foundation
import SQLite3

/// Singleton data store using direct C SQLite3 API.
/// The sqlite3* handle is opened/closed with the popover lifecycle.
final class TaskStore {

    static let shared = TaskStore()

    private var db: OpaquePointer?
    private var cachedActiveCount: Int = 0

    private init() {}

    // MARK: - Database Path

    private var databasePath: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                   in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MenuBarTodo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("tasks.db").path
    }

    // MARK: - Connection Lifecycle

    func open() {
        guard db == nil else { return }

        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databasePath, &db, flags, nil) == SQLITE_OK else {
            print("[TaskStore] Failed to open database: \(errorMessage)")
            return
        }

        configurePragmas()
        createTableIfNeeded()
        cachedActiveCount = queryActiveCount()
    }

    func close() {
        guard let db = db else { return }
        sqlite3_close_v2(db)
        self.db = nil
        // Aggressively reclaim SQLite internal pools
        sqlite3_release_memory(Int32.max)
    }

    var isOpen: Bool { db != nil }

    // MARK: - PRAGMA Configuration

    private func configurePragmas() {
        exec("PRAGMA journal_mode = WAL")
        exec("PRAGMA cache_size = 64")
        exec("PRAGMA page_size = 4096")
        exec("PRAGMA auto_vacuum = INCREMENTAL")
        exec("PRAGMA synchronous = NORMAL")
        exec("PRAGMA wal_autocheckpoint = 100")
    }

    // MARK: - Schema

    private static let schemaVersion = 1

    private func createTableIfNeeded() {
        let sql = """
            CREATE TABLE IF NOT EXISTS tasks (
                id          BLOB(16) PRIMARY KEY NOT NULL,
                title       TEXT NOT NULL,
                note        TEXT,
                priority    INTEGER NOT NULL DEFAULT 0,
                is_completed INTEGER NOT NULL DEFAULT 0,
                due_date    INTEGER,
                sort_order  INTEGER NOT NULL DEFAULT 0,
                created_at  INTEGER NOT NULL,
                updated_at  INTEGER NOT NULL,
                completed_at INTEGER
            );

            CREATE INDEX IF NOT EXISTS idx_tasks_active
                ON tasks(is_completed, sort_order);

            CREATE INDEX IF NOT EXISTS idx_tasks_due
                ON tasks(due_date, is_completed);

            CREATE INDEX IF NOT EXISTS idx_tasks_priority
                ON tasks(priority, is_completed);
            """
        exec(sql)
        setUserVersion(TaskStore.schemaVersion)
    }

    // MARK: - CRUD Operations

    func insertTask(_ task: TaskItem) {
        let sql = """
            INSERT INTO tasks (id, title, note, priority, is_completed,
                               due_date, sort_order, created_at, updated_at, completed_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        guard let stmt = prepare(sql) else { return }
        defer { sqlite3_finalize(stmt) }

        bindBlob(stmt, index: 1, data: task.id)
        bindText(stmt, index: 2, text: task.title)
        bindOptionalText(stmt, index: 3, text: task.note)
        sqlite3_bind_int(stmt, 4, Int32(task.priority.rawValue))
        sqlite3_bind_int(stmt, 5, task.isCompleted ? 1 : 0)
        bindOptionalDate(stmt, index: 6, date: task.dueDate)
        sqlite3_bind_int(stmt, 7, task.sortOrder)
        sqlite3_bind_int64(stmt, 8, Int64(task.createdAt.timeIntervalSince1970))
        sqlite3_bind_int64(stmt, 9, Int64(task.updatedAt.timeIntervalSince1970))
        bindOptionalDate(stmt, index: 10, date: task.completedAt)

        if sqlite3_step(stmt) != SQLITE_DONE {
            print("[TaskStore] Insert failed: \(errorMessage)")
        }
        cachedActiveCount = queryActiveCount()
    }

    func fetchTasks(completed: Bool? = nil) -> [TaskItem] {
        var sql = "SELECT id, title, note, priority, is_completed, due_date, sort_order, created_at, updated_at, completed_at FROM tasks"
        if let completed = completed {
            sql += " WHERE is_completed = \(completed ? 1 : 0)"
        }
        sql += " ORDER BY sort_order ASC, created_at DESC"

        guard let stmt = prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }

        var tasks: [TaskItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let task = readTask(from: stmt)
            tasks.append(task)
        }
        return tasks
    }

    func updateTask(_ task: TaskItem) {
        let sql = """
            UPDATE tasks SET title=?, note=?, priority=?, is_completed=?,
                             due_date=?, sort_order=?, updated_at=?, completed_at=?
            WHERE id=?
            """
        guard let stmt = prepare(sql) else { return }
        defer { sqlite3_finalize(stmt) }

        bindText(stmt, index: 1, text: task.title)
        bindOptionalText(stmt, index: 2, text: task.note)
        sqlite3_bind_int(stmt, 3, Int32(task.priority.rawValue))
        sqlite3_bind_int(stmt, 4, task.isCompleted ? 1 : 0)
        bindOptionalDate(stmt, index: 5, date: task.dueDate)
        sqlite3_bind_int(stmt, 6, task.sortOrder)
        sqlite3_bind_int64(stmt, 7, Int64(task.updatedAt.timeIntervalSince1970))
        bindOptionalDate(stmt, index: 8, date: task.completedAt)
        bindBlob(stmt, index: 9, data: task.id)

        if sqlite3_step(stmt) != SQLITE_DONE {
            print("[TaskStore] Update failed: \(errorMessage)")
        }
        cachedActiveCount = queryActiveCount()
    }

    func deleteTask(id: Data) {
        let sql = "DELETE FROM tasks WHERE id = ?"
        guard let stmt = prepare(sql) else { return }
        defer { sqlite3_finalize(stmt) }

        bindBlob(stmt, index: 1, data: id)
        if sqlite3_step(stmt) != SQLITE_DONE {
            print("[TaskStore] Delete failed: \(errorMessage)")
        }
        cachedActiveCount = queryActiveCount()
    }

    func toggleTaskCompletion(_ task: inout TaskItem) {
        task.isCompleted.toggle()
        task.updatedAt = Date()
        task.completedAt = task.isCompleted ? Date() : nil
        updateTask(task)
    }

    func clearCompletedTasks() {
        exec("DELETE FROM tasks WHERE is_completed = 1")
        cachedActiveCount = queryActiveCount()
    }

    func updateSortOrders(_ tasks: [TaskItem]) {
        exec("BEGIN TRANSACTION")
        let sql = "UPDATE tasks SET sort_order = ? WHERE id = ?"
        for task in tasks {
            guard let stmt = prepare(sql) else { continue }
            sqlite3_bind_int(stmt, 1, task.sortOrder)
            bindBlob(stmt, index: 2, data: task.id)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
        exec("COMMIT")
    }

    // MARK: - Count

    func activeTaskCount() -> Int {
        guard db != nil else { return cachedActiveCount }
        return queryActiveCount()
    }

    private func queryActiveCount() -> Int {
        guard db != nil else { return 0 }
        let sql = "SELECT COUNT(*) FROM tasks WHERE is_completed = 0"
        guard let stmt = prepare(sql) else { return 0 }
        defer { sqlite3_finalize(stmt) }
        if sqlite3_step(stmt) == SQLITE_ROW {
            let count = Int(sqlite3_column_int(stmt, 0))
            cachedActiveCount = count
            return count
        }
        return 0
    }

    // MARK: - Row Reading

    private func readTask(from stmt: OpaquePointer) -> TaskItem {
        let idBytes = sqlite3_column_blob(stmt, 0)
        let idLen = sqlite3_column_bytes(stmt, 0)
        let id = Data(bytes: idBytes!, count: Int(idLen))

        let title = String(cString: sqlite3_column_text(stmt, 1))
        let note: String? = sqlite3_column_type(stmt, 2) != SQLITE_NULL
            ? String(cString: sqlite3_column_text(stmt, 2)) : nil

        let priority = TaskPriority(rawValue: UInt8(sqlite3_column_int(stmt, 3))) ?? .none
        let isCompleted = sqlite3_column_int(stmt, 4) != 0

        let dueDate: Date? = sqlite3_column_type(stmt, 5) != SQLITE_NULL
            ? Date(timeIntervalSince1970: Double(sqlite3_column_int64(stmt, 5))) : nil

        let sortOrder = sqlite3_column_int(stmt, 6)

        let createdAt = Date(timeIntervalSince1970: Double(sqlite3_column_int64(stmt, 7)))
        let updatedAt = Date(timeIntervalSince1970: Double(sqlite3_column_int64(stmt, 8)))

        let completedAt: Date? = sqlite3_column_type(stmt, 9) != SQLITE_NULL
            ? Date(timeIntervalSince1970: Double(sqlite3_column_int64(stmt, 9))) : nil

        return TaskItem(id: id, title: title, note: note, priority: priority,
                        isCompleted: isCompleted, dueDate: dueDate, sortOrder: Int32(sortOrder),
                        createdAt: createdAt, updatedAt: updatedAt, completedAt: completedAt)
    }

    // MARK: - SQLite Helpers

    private func prepare(_ sql: String) -> OpaquePointer? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("[TaskStore] Prepare failed: \(errorMessage) — SQL: \(sql.prefix(80))")
            return nil
        }
        return stmt
    }

    private func exec(_ sql: String) {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            print("[TaskStore] Exec failed: \(errorMessage) — SQL: \(sql.prefix(80))")
            return
        }
    }

    private func bindBlob(_ stmt: OpaquePointer, index: Int32, data: Data) {
        _ = data.withUnsafeBytes { ptr in
            sqlite3_bind_blob(stmt, index, ptr.baseAddress, Int32(data.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
    }

    private func bindText(_ stmt: OpaquePointer, index: Int32, text: String) {
        sqlite3_bind_text(stmt, index, (text as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }

    private func bindOptionalText(_ stmt: OpaquePointer, index: Int32, text: String?) {
        if let text = text {
            bindText(stmt, index: index, text: text)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private func bindOptionalDate(_ stmt: OpaquePointer, index: Int32, date: Date?) {
        if let date = date {
            sqlite3_bind_int64(stmt, index, Int64(date.timeIntervalSince1970))
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private var errorMessage: String {
        if let msg = sqlite3_errmsg(db) {
            return String(cString: msg)
        }
        return "unknown error"
    }

    private func setUserVersion(_ version: Int) {
        exec("PRAGMA user_version = \(version)")
    }
}
