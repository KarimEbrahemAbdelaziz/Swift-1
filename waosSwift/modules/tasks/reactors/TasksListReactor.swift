/**
 * Dependencies
 */

import ReactorKit
import Differentiator

/**
 * Reactor
 */

typealias TasksSections = SectionModel<Void, TasksCellReactor>

final class TasksListReactor: Reactor {

    // MARK: Constants

    // user actions
    enum Action {
        // task
        case refresh([Tasks])
        case get
        case delete(IndexPath)
        // Notificaitons
        case getIndexPath(String)
        // user
        case checkUserToken
        case checkUserTerms
    }

    // state changes
    enum Mutation {
        // task
        case set([Tasks])
        case setRefreshing(Bool)
        // Notificaitons
        case setIndexPath(String)
        // user
        case setTerms(Pages?)
        // default
        case success(String)
        case error(CustomError)
    }

    // the current view state
    struct State {
        // Tasks
        var tasks: [Tasks]
        var sections: [TasksSections]
        var isRefreshing: Bool
        // Notificaitons
        var indexPath: IndexPath?
        // user
        var terms: Pages?

        init() {
            // task
            self.tasks = []
            self.sections = [TasksSections(model: Void(), items: [])]
            self.isRefreshing = false
            // user
            self.terms = nil
        }
    }

    // MARK: Properties

    let provider: AppServicesProviderType
    let initialState: State

    // MARK: Initialization

    init(provider: AppServicesProviderType) {
        self.provider = provider
        self.initialState = State()
    }

    // MARK: Transform -> Merges two observables into a single observabe : 1. Action observable from Reactor 2. Action observable from global state

    func transform(action: Observable<Action>) -> Observable<Action> {
        let refresh = self.provider.tasksService.tasks
            .filterNil()
            .distinctUntilChanged()
            .map { Action.refresh($0) }
        return Observable.of(action, refresh).merge()
    }

    // MARK: Action -> Mutation (mutate() receives an Action and generates an Observable<Mutation>)

    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        // refresh
        case let .refresh(tasks):
            log.verbose("♻️ Action -> Mutation : refresh")
            return .just(.set(tasks))
        // get
        case .get:
            guard !self.currentState.isRefreshing else { return .empty() }
            log.verbose("♻️ Action -> Mutation : get")
            return Observable.concat([
                .just(.setRefreshing(true)),
                self.provider.tasksService
                    .list()
                    .map { result in
                        switch result {
                        case let .success(result): return .set(result.data)
                        case let .error(err): return .error(err)
                        }
                    },
                .just(.setRefreshing(false))
            ])
        // delete
        case let .delete(i):
            log.verbose("♻️ Action -> Mutation : delete")
            let task = self.currentState.sections[i].currentState
            return self.provider.tasksService
                .delete(task)
                .map { result in
                    switch result {
                    case .success: return .success("delete")
                    case let .error(err): return .error(err)
                    }
                }
        // notification
        case let .getIndexPath(id):
            log.verbose("♻️ Action -> Mutation : getIndexPath")
            return .just(.setIndexPath(id))
        // check user token when open application
        case .checkUserToken:
            log.verbose("♻️ Action -> Mutation : checkUserToken")
            switch getTokenStatus() {
            case .isOk:
                return .just(.success("token ok"))
            case .toDefine:
                self.provider.preferencesService.isLogged = false
                return .just(.success("token to define"))
            case .toRenew:
                // check terms
                return self.provider.authService
                    .token()
                    .map { result in
                        switch result {
                        case let .success(response):
                            UserDefaults.standard.set(response.tokenExpiresIn, forKey: "CookieExpire")
                            UserDefaults.standard.set(response.user.terms, forKey: "Terms")
                            // also check terms update
                            return .success("token renewed")
                        case let .error(err):
                            self.provider.preferencesService.isLogged = false
                            return .error(err)
                        }
                    }
            }
        // check terms and conditions
        case .checkUserTerms:
            log.verbose("♻️ Action -> Mutation : checkUserTerms")
            if(getTokenStatus() == .toRenew || UserDefaults.standard.value(forKey: "Terms") == nil) {
                return  self.provider.homeService
                    .getPages(.page("terms"))
                    .map { result in
                        switch result {
                        case let .success(result):
                            let termsStatus = getTermsStatus(terms: result.data[0].updatedAt)
                            return termsStatus ? .setTerms(nil): .setTerms(result.data[0])
                        case let .error(err): return .error(err)
                        }
                    }
            } else {
                return .empty()
            }

        }
    }

    // MARK: Mutation -> State (reduce() generates a new State from a previous State and a Mutation)

    func reduce(state: State, mutation: Mutation) -> State {
        var state = state
        switch mutation {
        // refreshing
        case let .setRefreshing(isRefreshing):
            log.verbose("♻️ Mutation -> State : setRefreshing")
            state.isRefreshing = isRefreshing
        // set
        case let .set(tasks):
            log.verbose("♻️ Mutation -> State : set")
            let difference = tasks.difference(from: state.tasks)
            state.tasks = state.tasks.applying(difference) ?? []
            for change in difference {
                switch change {
                case let .remove(index, _, _):
                    state.sections.remove(at: IndexPath(item: index, section: 0))
                case let .insert(index, element, _):
                    state.sections.insert(TasksCellReactor(task: element), at: IndexPath(item: index, section: 0))
                }
            }
        // notification
        case let .setIndexPath(id):
            log.verbose("♻️ Mutation -> State : setIndexPath")
            if let section = state.sections.firstIndex(where: { $0.items.firstIndex(where: { $0.currentState.id == id }) != nil ? true : false }) {
                if let row = state.sections[section].items.firstIndex(where: { $0.currentState.id == id }) {
                    state.indexPath = IndexPath(row: row, section: section)
                }
            }
        // user
        case let .setTerms(terms):
            log.verbose("♻️ Mutation -> State : setTerms")
            state.terms = terms
        // success
        case let .success(success):
            log.verbose("♻️ Mutation -> State : succes \(success)")
        // error
        case let .error(error):
            log.verbose("♻️ Mutation -> State : error \(error)")
            let _error: DisplayError
            if error.code == 401 {
                self.provider.preferencesService.isLogged = false
                _error = DisplayError(title: "jwt", description: "Wrong Password or Email.", type: error.type)
            } else {
                _error = DisplayError(title: error.message, description: (error.description ?? "Unknown error"), type: error.type)
            }
            ToastCenter.default.cancelAll()
            Toast(text: _error.description, delay: 0, duration: Delay.long).show()
        }
        return state
    }

    // reactor init

    func addReactor() -> TasksViewReactor {
        return TasksViewReactor(provider: self.provider, mode: .add)
    }

    func editReactor(_ taskCellReactor: TasksCellReactor) -> TasksViewReactor {
        let task = taskCellReactor.currentState
        return TasksViewReactor(provider: self.provider, mode: .edit(task))
    }

    func termsReactor(terms: Pages) -> HomeTermsReactor {
        return HomeTermsReactor(provider: self.provider, terms: terms, style: .classic, displayLinks: true)
    }
}
