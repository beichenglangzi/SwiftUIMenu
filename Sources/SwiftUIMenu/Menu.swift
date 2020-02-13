//
//  Menu.swift
//  CustomNavigations
//
//  Created by Fernando Moya de Rivas on 16/12/2019.
//  Copyright © 2019 Fernando Moya de Rivas. All rights reserved.
//

import SwiftUI

///
/// `Menu` allows you to implement a side-sliding menu to navigate through App screen.
///
/// #Example#
/// ```swift
/// Menu(indexSelected: self.$index,
///      isOpen: self.$isMenuOpen,
///      menuItems: menuItems,
///      menuItemRow: { index in
///          Text("Option \(index)")
///      },
///      menuItemContent: { section in
///          Text("Welcome to section \(section)")
///      })
/// })
/// ```
public struct Menu<Item, Row, Content>: View where Item: Identifiable & Equatable, Row: View, Content: View {

    /*** Arguments  ***/

    /// `true` if the menu drawer is visible
    @Binding private var isOpen: Bool

    /// Dragged translation. Limited by the size of `sectionList`. Will be zero if dragging is not allowed
    @State private var draggingOffset: CGFloat = 0

    /// Space available
    @State private var size: CGSize = .zero

    /// Index of the current section
    @Binding private var indexSelected: Int

    /// Elements that will populate the menu drawer
    var menuItems: [Item]

    /// Factory block to build each row in the menu drawer list
    var menuItemRow: (Item) -> Row

    /// Factory method to build the content of the selected section
    var menuItemContent: (Int) -> Content

    /*** Buildable ***/

    /// Indicates the side the menu drawer should slide from
    var alignment: Alignment = .left

    /// Customizes the way the menu drawer is revealed
    var style: Style = .push

    /// `true` if the content should shade when the drawer is open
    var shouldShadeContent = false

    /// `true` if `Menu` can be open by dragging
    var allowDragging = true

    /// Section list size proportion relative to the menu size
    var overlappingRatio: CGFloat = 1

    /// Defines the position of the menu drawer
    public enum Alignment {

        /// The menu drawer slides from the left
        case left

        /// The menu drawer slides from the right
        case right
    }

    /// Defines how the menu drawer will be presented in the screen
    public enum Style {

        /// The menu drawer sill slide and stack it self over the content
        case overlap

        /// The menu drawer will push the content off the screen
        case push

        /// The menu drawer will pop in the screen by stretching itself with a centered anchor
        case stretch
    }

    /// Initializes a new `Menu`
    ///
    /// - Parameter indexSelected: Binding to the current section index
    /// - Parameter isOpen: Binding to the menu drawer state
    /// - Parameter menuItems: Array of elements to populate the menu drawer
    /// - Parameter menuItemRow: Factory method to build the section list
    /// - Parameter menuItemContent: Factory method to build de current section content
    public init(indexSelected: Binding<Int>, isOpen: Binding<Bool>, menuItems: [Item], @ViewBuilder menuItemRow: @escaping (Item) -> Row, @ViewBuilder menuItemContent: @escaping (Int) -> Content) {
        self._indexSelected = indexSelected
        self._isOpen = isOpen
        self.menuItems = menuItems
        self.menuItemRow = menuItemRow
        self.menuItemContent = menuItemContent
    }
    
    public var body: some View {
        let view = ZStack {
            if style == .stretch {
                sectionList
            }
            Group {
                sectionContent
                shade
            }.offset(sectionContentOffset)

            if style != .stretch {
                sectionList
            }
        }.sizeTrackable($size)

        guard allowDragging else { return AnyView(view) }

        return AnyView(view
            .gesture(
                DragGesture()
                    .onChanged(onDraggingChanged(value:))
                    .onEnded(onDraggingEnded(value:)))
            )
    }
}

// MARK: Helpers

extension Menu {

    /// `true` if the menu drawer is hidden
    var isClosed: Bool {
        !isOpen
    }

    /// Handles `DragGesture.onChanged` event
    func onDraggingChanged(value: DragGesture.Value) {
        let draggingOffset: CGFloat
        if alignment == .left {
            draggingOffset = isClosed ? max(0, min(self.sectionListSize.width, value.translation.width)) : min(0, max(-self.sectionListSize.width, value.translation.width))
        } else {
            draggingOffset = isClosed ? min(0, max(-self.sectionListSize.width, value.translation.width)) : max(0, min(self.sectionListSize.width, value.translation.width))
        }

        withAnimation {
            self.draggingOffset = draggingOffset
        }
    }

    /// Handles `DragGesture.onEnded` event
    func onDraggingEnded(value: DragGesture.Value) {
        withAnimation {
            if abs(self.draggingOffset) > self.sectionListSize.width / 2 {
                self.isOpen.toggle()
            }
            self.draggingOffset = 0
        }
    }

    /// Drawer menu size
    var sectionListSize: CGSize {
        CGSize(width: overlappingRatio * size.width,
               height: size.height)
    }

    /// Drawer menu offset. Depends on the chosen menu style
    var sectionListOffset: CGSize {
        let multiplier: CGFloat = alignment == .left ? 1 : -1
        let stretchFactor: CGFloat = style == .stretch ? 0.5 : 1
        let hiddenOffset = -sectionListSize.width * stretchFactor - (size - sectionListSize).width * 0.5

        guard style != .push else {
            return CGSize(width: hiddenOffset * multiplier + sectionContentOffset.width,
                          height: 0)
        }

        let xOffset = self.isOpen ? hiddenOffset + sectionListSize.width * stretchFactor : hiddenOffset
        return CGSize(width: xOffset * multiplier + draggingOffset * stretchFactor,
                      height: 0)
    }

    /// Section content offset. Depends on the chosen menu style
    var sectionContentOffset: CGSize {
        guard style != .overlap else { return .zero }

        let multiplier: CGFloat = alignment == .left ? 1 : -1
        let xOffset = isOpen ? sectionListSize.width : 0

        return CGSize(width: xOffset * multiplier + draggingOffset,
                      height: 0)
    }

    /// Manages the opacity of the section content when `shouldShadeContent` is enabled.
    /// Will return a value, where `0 <= value <= 0.6`
    var shadeOpacity: Double {
        guard shouldShadeContent else { return 0 }
        guard sectionListSize.width > 0 else { return 0 }

        let threshold: Double = 0.6
        guard abs(draggingOffset) > 0 else { return isClosed ? 0 : threshold }

        let ratio = abs(draggingOffset) / sectionListSize.width
        return isClosed ? Double(ratio) * threshold : (1 - Double(ratio)) * threshold
    }
}

// MARK: Subviews

extension Menu {

    /// Shade applied to the section content
    var shade: some View {
        Rectangle()
            .fill(Color.black.opacity(shadeOpacity))
            .allowsHitTesting(false)
    }

    /// The content shown as per `indexSelected`
    private var sectionContent: some View {
        menuItemContent(indexSelected)
            .onTapGesture (perform: {
                withAnimation(Animation.easeOut(duration: 0.25)) {
                    self.isOpen = false
                }
            })
    }

    /// The drawer menu that slides from the side
    private var sectionList: some View {
        List {
            ForEach(menuItems) { item in
                self.menuItemRow(item)
                    .onTapGesture (perform: {
                        withAnimation(Animation.easeOut(duration: 0.25)) {
                            self.isOpen = false
                            self.indexSelected = self.menuItems.firstIndex(of: item)!
                        }
                    })
            }
        }
        .frame(size: sectionListSize)
        .offset(sectionListOffset)
    }
    
}