/**
 * Service
 */

protocol TasksServiceType {
    var tasks: Observable<[Tasks]?> { get }

    func list() -> Observable<MyResult<TasksResponse, NetworkError>>
    func create(_ task: Tasks) -> Observable<MyResult<TaskResponse, NetworkError>>
    func save(_ task: Tasks) -> Observable<MyResult<TaskResponse, NetworkError>>
    func delete(_ task: Tasks) -> Observable<MyResult<DeleteResponse, NetworkError>>
}

final class TasksService: CoreService, TasksServiceType {
    fileprivate let networking = Networking<TasksApi>(plugins: [CookiePlugin()])

    // temporary array
    var defaultTasks: [Tasks] = [Tasks(id: "String", title: "String")]

    fileprivate let tasksSubject = ReplaySubject<[Tasks]?>.create(bufferSize: 1)
    lazy var tasks: Observable<[Tasks]?> = self.tasksSubject.asObservable()
        .startWith(nil)
        .share(replay: 1)

    func list() -> Observable<MyResult<TasksResponse, NetworkError>> {
        log.verbose("🔌 service : get")
        return self.networking
            .request(.list)
            .map(TasksResponse.self)
            .map { response in
                self.defaultTasks = response.data
                return response
            }
            .asObservable()
            .map(MyResult.success)
            .catchError { err in .just(.error(getNetworkError(err)))}
    }

    func create(_ task: Tasks) -> Observable<MyResult<TaskResponse, NetworkError>> {
        log.verbose("🔌 service : create")
        return self.networking
            .request(.create(task))
            .map(TaskResponse.self)
            .map { response in
                self.defaultTasks.insert(response.data, at: 0)
                self.tasksSubject.onNext(self.defaultTasks)
                return response
            }
            .asObservable()
            .map(MyResult.success)
            .catchError { err in .just(.error(getNetworkError(err)))}
    }

    func save(_ task: Tasks) -> Observable<MyResult<TaskResponse, NetworkError>> {
        log.verbose("🔌 service : save")
        return self.networking
            .request(.update(task))
            .map(TaskResponse.self)
            .map { response in
                if let index = self.defaultTasks.firstIndex(where: { $0.id == response.data.id }) {
                    self.defaultTasks[index] = response.data
                }
                self.tasksSubject.onNext(self.defaultTasks)
                return response
            }
            .asObservable()
            .map(MyResult.success)
            .catchError { err in .just(.error(getNetworkError(err)))}
    }

    func delete(_ task: Tasks) -> Observable<MyResult<DeleteResponse, NetworkError>> {
        log.verbose("🔌 service : delete")
        return self.networking
            .request(.delete(task))
            .map(DeleteResponse.self)
            .map { response in
                if let index = self.defaultTasks.firstIndex(where: { $0.id == response.data.id }) {
                    self.defaultTasks.remove(at: index)
                }
                self.tasksSubject.onNext(self.defaultTasks)
                return response
            }
            .asObservable()
            .map(MyResult.success)
            .catchError { err in .just(.error(getNetworkError(err)))}
    }
}
