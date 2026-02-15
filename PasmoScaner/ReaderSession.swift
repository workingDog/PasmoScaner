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
            session?.alertMessage = String(localized: "TAPPASMO")
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
        finish(with: .failure(error))
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first,
              case let .feliCa(feliCa) = tag else {
            finish(with: .failure(NSError(domain: "NotFeliCa", code: -1)))
            session.invalidate()
            return
        }
        session.connect(to: tag) { error in
            if let error {
                self.finish(with: .failure(error))
            } else {
                self.finish(with: .success(feliCa))
            }
        }
    }
    
    private func finish(with result: Result<NFCFeliCaTag, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        switch result {
            case .success(let tag): continuation.resume(returning: tag)
            case .failure(let error): continuation.resume(throwing: error)
        }
    }
   
}

