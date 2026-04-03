import XCTest
@testable import MenuBarTodo

final class TaskStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TaskStore.shared.open()
    }

    override func tearDown() {
        TaskStore.shared.clearCompletedTasks()
        // Clean up all tasks
        let all = TaskStore.shared.fetchTasks(completed: nil)
        for task in all {
            TaskStore.shared.deleteTask(id: task.id)
        }
        TaskStore.shared.close()
        super.tearDown()
    }

    // MARK: - CRUD Tests

    func testInsertAndFetch() {
        let task = TaskItem(title: "Test task")
        TaskStore.shared.insertTask(task)

        let tasks = TaskStore.shared.fetchTasks(completed: false)
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.title, "Test task")
    }

    func testUpdateTask() {
        var task = TaskItem(title: "Original")
        TaskStore.shared.insertTask(task)

        task.title = "Updated"
        task.priority = .high
        task.updatedAt = Date()
        TaskStore.shared.updateTask(task)

        let tasks = TaskStore.shared.fetchTasks(completed: false)
        XCTAssertEqual(tasks.first?.title, "Updated")
        XCTAssertEqual(tasks.first?.priority, .high)
    }

    func testDeleteTask() {
        let task = TaskItem(title: "To delete")
        TaskStore.shared.insertTask(task)
        TaskStore.shared.deleteTask(id: task.id)

        let tasks = TaskStore.shared.fetchTasks(completed: nil)
        XCTAssertTrue(tasks.isEmpty)
    }

    func testToggleCompletion() {
        var task = TaskItem(title: "Toggle me")
        TaskStore.shared.insertTask(task)

        TaskStore.shared.toggleTaskCompletion(&task)
        XCTAssertTrue(task.isCompleted)
        XCTAssertNotNil(task.completedAt)

        let completedTasks = TaskStore.shared.fetchTasks(completed: true)
        XCTAssertEqual(completedTasks.count, 1)
    }

    func testClearCompleted() {
        var task1 = TaskItem(title: "Active task")
        var task2 = TaskItem(title: "Done task")
        TaskStore.shared.insertTask(task1)
        TaskStore.shared.insertTask(task2)
        TaskStore.shared.toggleTaskCompletion(&task2)

        TaskStore.shared.clearCompletedTasks()

        let all = TaskStore.shared.fetchTasks(completed: nil)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.title, "Active task")
    }

    func testActiveCount() {
        TaskStore.shared.insertTask(TaskItem(title: "Task 1"))
        TaskStore.shared.insertTask(TaskItem(title: "Task 2"))
        var task3 = TaskItem(title: "Task 3")
        TaskStore.shared.insertTask(task3)
        TaskStore.shared.toggleTaskCompletion(&task3)

        XCTAssertEqual(TaskStore.shared.activeTaskCount(), 2)
    }

    // MARK: - Data Model Tests

    func testTaskItemIsValueType() {
        var task1 = TaskItem(title: "Original")
        var task2 = task1  // Should be a copy (struct)
        task2.title = "Modified"

        XCTAssertEqual(task1.title, "Original")
        XCTAssertEqual(task2.title, "Modified")
    }

    func testUUIDisSixteenBytes() {
        let task = TaskItem(title: "UUID test")
        XCTAssertEqual(task.id.count, 16)
    }

    // MARK: - Connection Lifecycle Tests

    func testOpenClose() {
        // Already open from setUp
        XCTAssertTrue(TaskStore.shared.isOpen)

        TaskStore.shared.close()
        XCTAssertFalse(TaskStore.shared.isOpen)

        // Reopen for tearDown
        TaskStore.shared.open()
    }

    func testDoubleOpenIsIdempotent() {
        TaskStore.shared.open() // Already open
        XCTAssertTrue(TaskStore.shared.isOpen)
    }

    // MARK: - Priority Tests

    func testPriorityLevels() {
        var task = TaskItem(title: "Priority test", priority: .medium)
        TaskStore.shared.insertTask(task)

        let tasks = TaskStore.shared.fetchTasks(completed: false)
        XCTAssertEqual(tasks.first?.priority, .medium)
    }

    // MARK: - Due Date Tests

    func testDueDate() {
        let dueDate = Date().addingTimeInterval(86400) // Tomorrow
        var task = TaskItem(title: "Due test", dueDate: dueDate)
        TaskStore.shared.insertTask(task)

        let tasks = TaskStore.shared.fetchTasks(completed: false)
        XCTAssertNotNil(tasks.first?.dueDate)

        // Within 1 second tolerance (Unix timestamp precision)
        let diff = abs(tasks.first!.dueDate!.timeIntervalSince(dueDate))
        XCTAssertLessThan(diff, 1.0)
    }
}
