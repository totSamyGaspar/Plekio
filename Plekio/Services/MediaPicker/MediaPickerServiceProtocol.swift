//
//  MediaPickerServiceProtocol.swift
//  Plekio
//
//  Created by Edward Gasparian on 20.05.2026.
//

import SwiftUI

protocol MediaPickerServiceProtocol {
    func pickImage(source: MediaSource) async throws -> UIImage
}
