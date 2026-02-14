//
//  ReaderSession.swift
//  PasmoScaner
//
//  Created by Ringo Wathelet on 2026/02/04.
//
import CoreNFC


final class ReaderSession: NSObject, NFCTagReaderSessionDelegate {

    private var session: NFCTagReaderSession?
    private var continuation: CheckedContinuation<NFCFeliCaTag, Error>?

    func scan() async throws -> NFCFeliCaTag {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            session = NFCTagReaderSession(pollingOption: .iso18092, delegate: self)
            session?.alertMessage = "Tap PASMO on Neko"
            session?.begin()
        }
    }
    
    func invalidate(errorMessage: String) {
        session?.invalidate(errorMessage: errorMessage)
    }
    
    func invalidate() {
        session?.invalidate()
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first,
              case let .feliCa(feliCa) = tag else {
            session.invalidate(errorMessage: "Not a FeliCa card")
            return
        }
        session.connect(to: tag) { error in
            if let error {
                self.continuation?.resume(throwing: error)
            } else {
                self.continuation?.resume(returning: feliCa)
            }
            self.continuation = nil
        }
    }
   
}

