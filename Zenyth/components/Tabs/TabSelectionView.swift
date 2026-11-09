//
//  TabSelectionView.swift
//  Zenyth
//
//  Created by Hugo Persson on 2024-08-25.
//

import Defaults
import SwiftUI

struct TabModel: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let view: NotchViews
}

let tabs = [
    TabModel(label: "Home", icon: "house.fill", view: .home),
    TabModel(label: "Shelf", icon: "tray.fill", view: .shelf),
    TabModel(label: "Stats", icon: "chart.xyaxis.line", view: .stats),
    TabModel(label: "Clipboard", icon: "clipboard.fill", view: .clipboard)
]

struct TabSelectionView: View {
    @ObservedObject var coordinator = ZenythViewCoordinator.shared
    @Default(.showTabArrowButtons) var showTabArrowButtons
    @Namespace var animation

    var body: some View {
        HStack(spacing: 4) {
            if showTabArrowButtons {
                Button(action: {
                    coordinator.selectPreviousTab()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(coordinator.canSelectPreviousTab ? Color.white.opacity(0.85) : Color.white.opacity(0.2))
                        .frame(width: 18, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!coordinator.canSelectPreviousTab)
            }

            HStack(spacing: 0) {
                ForEach(tabs) { tab in
                    TabButton(label: tab.label, icon: tab.icon, selected: coordinator.currentView == tab.view) {
                        withAnimation(.smooth) {
                            coordinator.currentView = tab.view
                        }
                    }
                    .frame(height: 26)
                    .foregroundStyle(tab.view == coordinator.currentView ? .white : .gray)
                    .background {
                        if tab.view == coordinator.currentView {
                            Capsule()
                                .fill(coordinator.currentView == tab.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                                .matchedGeometryEffect(id: "capsule", in: animation)
                        } else {
                            Capsule()
                                .fill(coordinator.currentView == tab.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                                .matchedGeometryEffect(id: "capsule", in: animation)
                                .hidden()
                        }
                    }
                }
            }
            .clipShape(Capsule())

            if showTabArrowButtons {
                Button(action: {
                    coordinator.selectNextTab()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(coordinator.canSelectNextTab ? Color.white.opacity(0.85) : Color.white.opacity(0.2))
                        .frame(width: 18, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!coordinator.canSelectNextTab)
            }
        }
    }
}

#Preview {
    ZenythHeader().environmentObject(ZenythViewModel())
}
