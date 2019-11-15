/**
 * Dependencies
 */

import UIKit
import ReactorKit

/**
 * Controller
 */

final class TasksCellController: CoreCellController, View {

    typealias Reactor = TasksCellReactor

    // MARK: UI

    let labelTitle = CoreUILabel().then {
        $0.numberOfLines = 2
        $0.textColor = UIColor(named: config["theme"]["themes"]["waos"]["onSurface"].string ?? "")
    }

    // MARK: Initializing

    override func initialize() {
        self.contentView.addSubview(self.labelTitle)
        self.contentView.backgroundColor = UIColor(named: config["theme"]["themes"]["waos"]["surface"].string ?? "")
    }

    // MARK: Binding

    func bind(reactor: Reactor) {
        self.labelTitle.text = reactor.currentState.title
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        self.labelTitle.snp.makeConstraints { make in
            make.left.equalTo(25)
            make.centerY.equalToSuperview()
        }
        self.labelTitle.sizeToFit()
    }
}
