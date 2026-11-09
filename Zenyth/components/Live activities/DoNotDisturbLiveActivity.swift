//
//  DoNotDisturbLiveActivity.swift
//  Zenyth
//
//  Derived from Atoll project.
//  Licensed under GNU General Public License v3.0.
//

import Defaults
import SwiftUI

struct DoNotDisturbLiveActivity: View {
    @EnvironmentObject var vm: ZenythViewModel
    @ObservedObject var dndManager = DoNotDisturbManager.shared

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "moon.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.indigo)
        }
        .padding(.horizontal, 4)
    }
}

