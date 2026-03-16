import XCTest
import AppKit
@testable import GreenshotMac

@MainActor
final class ToolSidebarInteractionTests: XCTestCase {

    // MARK: - All Tools Have Buttons

    func testAllAnnotationToolsHaveButtons() {
        let sidebar = ToolSidebarView()
        for tool in AnnotationTool.allCases {
            XCTAssertNotNil(sidebar.buttons[tool],
                "\(tool) should have a button in the sidebar")
        }
    }

    // MARK: - Select Tool Updates Button States

    func testSelectToolSetsCorrectButtonOn() {
        let sidebar = ToolSidebarView()
        sidebar.selectTool(.rectangle)

        XCTAssertEqual(sidebar.buttons[.rectangle]?.state, .on,
            "Selected tool button should be .on")
    }

    func testSelectToolSetsOtherButtonsOff() {
        let sidebar = ToolSidebarView()
        sidebar.selectTool(.rectangle)

        for (tool, button) in sidebar.buttons where tool != .rectangle {
            XCTAssertEqual(button.state, .off,
                "\(tool) button should be .off when rectangle is selected")
        }
    }

    func testSelectToolChangesClearsOldSelection() {
        let sidebar = ToolSidebarView()
        sidebar.selectTool(.rectangle)
        sidebar.selectTool(.ellipse)

        XCTAssertEqual(sidebar.buttons[.rectangle]?.state, .off)
        XCTAssertEqual(sidebar.buttons[.ellipse]?.state, .on)
    }

    // MARK: - Button Click Dispatches to Delegate

    func testToolButtonClickCallsDelegate() {
        let sidebar = ToolSidebarView()
        let delegate = MockToolSidebarDelegate()
        sidebar.delegate = delegate

        guard let button = sidebar.buttons[.arrow] else {
            XCTFail("Arrow tool button not found")
            return
        }

        sidebar.toolButtonClicked(button)

        XCTAssertEqual(delegate.lastTool, .arrow,
            "Clicking arrow button should dispatch .arrow to delegate")
    }

    func testToolButtonClickUpdatesButtonStates() {
        let sidebar = ToolSidebarView()
        let delegate = MockToolSidebarDelegate()
        sidebar.delegate = delegate

        guard let button = sidebar.buttons[.text] else {
            XCTFail("Text tool button not found")
            return
        }

        sidebar.toolButtonClicked(button)

        XCTAssertEqual(sidebar.buttons[.text]?.state, .on)
        XCTAssertEqual(sidebar.buttons[.select]?.state, .off)
    }

    // MARK: - Default Selection

    func testDefaultSelectionIsSelect() {
        let sidebar = ToolSidebarView()
        XCTAssertEqual(sidebar.buttons[.select]?.state, .on,
            "Select tool should be selected by default")
    }

    // MARK: - Button Configuration

    func testToolButtonsHaveTooltips() {
        let sidebar = ToolSidebarView()
        for (tool, button) in sidebar.buttons {
            XCTAssertNotNil(button.toolTip, "\(tool) button should have a tooltip")
            XCTAssertFalse(button.toolTip?.isEmpty ?? true, "\(tool) button tooltip should not be empty")
        }
    }

    func testToolButtonsHaveImages() {
        let sidebar = ToolSidebarView()
        for (tool, button) in sidebar.buttons {
            XCTAssertNotNil(button.image, "\(tool) button should have an image")
        }
    }
}

// MARK: - Mock Delegate

@MainActor
private final class MockToolSidebarDelegate: ToolSidebarDelegate {
    var lastTool: AnnotationTool?

    func toolSidebar(_ sidebar: ToolSidebarView, didSelectTool tool: AnnotationTool) {
        lastTool = tool
    }
}
