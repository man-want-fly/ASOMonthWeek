//
//  EventKitSupport.swift
//  CalLib
//
//  Created by mwf on 2023/8/14.
//

import EventKit
import UIKit

class EventKitSupport: NSObject {

    var savedEvent: EKEvent?

    var saveCompletion: ((Bool) -> Void)?

    let eventStore: EKEventStore
    private(set) var accessGranted = false

    init(eventStore: EKEventStore) {
        self.eventStore = eventStore
        super.init()
    }

    func checkEventStoreAccess(
        completion: @escaping (Bool) -> Void
    ) {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .notDetermined:
            requestCalendarAccess(completion: completion)
        case .restricted, .denied:
            accessDeniedForCalendar()
            completion(false)
        case .authorized:
            accessGrantedForCalendar()
            completion(true)
        @unknown default:
            fatalError("@unknown")
        }
    }

    func save(event: EKEvent, completion: @escaping (Bool) -> Void) {
        if event.hasRecurrenceRules {
            savedEvent = event
            saveCompletion = completion

            let title = NSLocalizedString("This is a repeating event.", comment: "")
            let msg = NSLocalizedString("What do you want to modify?", comment: "")
            let sheet = UIAlertView(
                title: title,
                message: msg,
                delegate: self,
                cancelButtonTitle: NSLocalizedString("Cancel", comment: ""),
                otherButtonTitles: NSLocalizedString("This event only", comment: ""),
                NSLocalizedString("All future events", comment: "")
            )

            sheet.show()
        } else {
            do {
                try eventStore.save(event, span: .thisEvent, commit: true)
                completion(true)
            } catch {
                print("Error - Could not save event: \(error)")
                completion(false)
            }
            saveCompletion = nil
        }
    }

    private func accessGrantedForCalendar() {
        accessGranted = true
    }

    private func requestCalendarAccess(completion: @escaping (Bool) -> Void) {
        eventStore.requestAccess(to: .event) { (granted, error) in
            DispatchQueue.main.async {
                if granted {
                    self.accessGrantedForCalendar()
                    completion(true)
                }
            }
            
        }
    }

    private func accessDeniedForCalendar() {
        let title = NSLocalizedString("Warning", comment: "")
        let msg = NSLocalizedString("Access to the calendar was not authorized", comment: "")
        let alert = UIAlertView(title: title, message: msg, delegate: nil, cancelButtonTitle: "OK")
        alert.show()
    }
}

extension EventKitSupport: UIAlertViewDelegate {

    func alertView(_ alertView: UIAlertView, clickedButtonAt buttonIndex: Int) {
        
        assert(savedEvent != nil, "Saved event is nil")

        if buttonIndex != 0 {
            var span: EKSpan = .thisEvent

            if buttonIndex == 1 {
                span = .thisEvent
            } else if buttonIndex == 2 {
                span = .futureEvents
            }

            do {
                try eventStore.save(savedEvent!, span: span, commit: true)
                saveCompletion?(true)
            } catch {
                print("Error - Could not save event: \(error.localizedDescription)")
                saveCompletion?(false)
            }
        }
        
        saveCompletion = nil
        savedEvent = nil
    }
}
