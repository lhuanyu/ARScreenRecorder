/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Utility class for showing messages above the AR view.
*/

import Foundation
import ARKit

/**
 Displayed at the top of the main interface of the app that allows users to see
 the status of the AR experience, as well as the ability to control restarting
 the experience altogether.
 - Tag: StatusViewController
*/
class StatusViewController: UIViewController {
    // MARK: - Types

    enum MessageType {
        case trackingStateEscalation
        case planeEstimation
        case contentPlacement
        case focusSquare

        static var all: [MessageType] = [
            .trackingStateEscalation,
            .planeEstimation,
            .contentPlacement,
            .focusSquare
        ]
    }

    // MARK: - IBOutlets

    @IBOutlet weak private var messagePanel: UIVisualEffectView!
    
    @IBOutlet weak private var messageLabel: UILabel!
    
    @IBOutlet weak private var restartExperienceButton: UIButton!

    // MARK: - Properties
    
    /// Trigerred when the "Restart Experience" button is tapped.
    var restartExperienceHandler: () -> Void = {}
    
    /// Seconds before the timer message should fade out. Adjust if the app needs longer transient messages.
    private let displayDuration: TimeInterval = 6
    
    // Timer for hiding messages.
    private var messageHideTimer: Timer?
    
    private var timers: [MessageType: Timer] = [:]
    
    // MARK: - Message Handling
	
	func showMessage(_ text: String, autoHide: Bool = true) {
        // Cancel any previous hide timer.
        messageHideTimer?.invalidate()

        messageLabel.text = text

        // Make sure status is showing.
        setMessageHidden(false, animated: true)

        if autoHide {
            messageHideTimer = Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: false, block: { [weak self] _ in
                self?.setMessageHidden(true, animated: true)
            })
        }
	}
    
	func scheduleMessage(_ text: String, inSeconds seconds: TimeInterval, messageType: MessageType) {
        cancelScheduledMessage(for: messageType)

        let timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false, block: { [weak self] timer in
            self?.showMessage(text)
            timer.invalidate()
		})

        timers[messageType] = timer
	}
    
    func cancelScheduledMessage(`for` messageType: MessageType) {
        timers[messageType]?.invalidate()
        timers[messageType] = nil
    }

    func cancelAllScheduledMessages() {
        for messageType in MessageType.all {
            cancelScheduledMessage(for: messageType)
        }
    }
    
    // MARK: - ARKit
    
	func showTrackingQualityInfo(for trackingState: ARCamera.TrackingState, autoHide: Bool) {
		showMessage(trackingState.presentationString, autoHide: autoHide)
	}
	
	func escalateFeedback(for trackingState: ARCamera.TrackingState, inSeconds seconds: TimeInterval) {
        cancelScheduledMessage(for: .trackingStateEscalation)

		let timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false, block: { [unowned self] _ in
            self.cancelScheduledMessage(for: .trackingStateEscalation)

            var message = trackingState.presentationString
            if let recommendation = trackingState.recommendation {
                message.append(": \(recommendation)")
            }

            self.showMessage(message, autoHide: false)
		})

        timers[.trackingStateEscalation] = timer
    }
    
    // MARK: - IBActions
    
    @IBAction private func restartExperience(_ sender: UIButton) {
        restartExperienceHandler()
    }
	
	// MARK: - Panel Visibility
    
	private func setMessageHidden(_ hide: Bool, animated: Bool) {
        // The panel starts out hidden, so show it before animating opacity.
        messagePanel.isHidden = false
        
        guard animated else {
            messagePanel.alpha = hide ? 0 : 1
            return
        }

        UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState], animations: {
            self.messagePanel.alpha = hide ? 0 : 1
        }, completion: nil)
	}
}

extension ARCamera.TrackingState {
    var presentationString: String {
        switch self {
        case .notAvailable:
            return "TRACKING UNAVAILABLE"
        case .normal:
            return "TRACKING NORMAL"
        case .limited(.excessiveMotion):
            return "TRACKING LIMITED\nExcessive motion"
        case .limited(.insufficientFeatures):
            return "TRACKING LIMITED\nLow detail"
        case .limited(.initializing):
            return "Initializing"
        }
    }

    var recommendation: String? {
        switch self {
        case .limited(.excessiveMotion):
            return "Try slowing down your movement, or reset the session."
        case .limited(.insufficientFeatures):
            return "Try pointing at a flat surface, or reset the session."
        default:
            return nil
        }
    }
}
