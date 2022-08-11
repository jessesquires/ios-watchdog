//
//  Created by Jesse Squires.
//  https://www.jessesquires.com
//
//  GitHub
//  https://github.com/jessesquires/ios-watchdog
//
//  Copyright © 2022-present Jesse Squires
//

import UIKit
import Watchdog

final class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        print("view did load")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        print("view did appear, sleep(5)")

        DispatchQueue.main.asyncAfter(deadline: .now()) {
            sleep(5)
        }
    }
}
