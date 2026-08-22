//
//  MockMediaPickerService.swift
//  PillFlowTests
//
//  Mock for MediaPickerServiceProtocol — lets AddMedicationViewModel's photo
//  selection/removal be tested without a real UIImagePickerController /
//  PHPickerViewController, which have nowhere to present in a unit test
//  (no active UIWindow scene).
//

import SwiftUI
@testable import PillFlow

final class MockMediaPickerService: MediaPickerServiceProtocol {

    /// What pickImage returns. If nil, throws MediaPickerError.cancelled,
    /// simulating the user cancelling the picker.
    var imageToReturn: UIImage?
    var errorToThrow: Error?

    private(set) var lastRequestedSource: MediaSource?

    func pickImage(source: MediaSource) async throws -> UIImage {
        lastRequestedSource = source
        if let errorToThrow {
            throw errorToThrow
        }
        guard let imageToReturn else {
            throw MediaPickerError.cancelled
        }
        return imageToReturn
    }
}
