# Implement Location Visibility Toggle

## Goal
Replace the Profile/Avatar selection button (Top-Left) with a **Location Visibility Toggle**.

## Specifications
1.  **Modes**:
    -   **Public (公開)**: Default. Icon: Green Circle.
    -   **Close Friends (摯友)**: Icon: Green Star (Five-pointed).
    -   **Off (關閉)**: Icon: Gray Circle.
2.  **Interaction**:
    -   **Collapsed**: Shows only the current mode's icon.
    -   **Expanded**: Animations open to the **Right**.
    -   Displays text options: "公開", "摯友", "關閉".
    -   Selecting an option updates the state and collapses the button.

## Proposed Changes

### [MODIFY] [passenger_home_page.dart](file:///c:/Works/WinterProject/ZooZoo_v1.0/zoozoo_v1/lib/features/passenger/home/presentation/pages/passenger_home_page.dart)

#### 1. Fix Layout & Overflow
-   **Problem**: The user-implemented `Stack` approach causes hit-testing issues (taps outside the 48px footprint are ignored) and visual overflow.
-   **Solution**: Revert to using `AnimatedContainer` directly within the `Row`. The `Spacer()` widget between the Toggle and the Right Buttons will automatically adjust (shrink) to accommodate the expanded toggle.
-   **Dimensions**: Increase expanded width to `260` or `280` to prevent "Right Overflowed" warnings on the inner content.

#### 2. Fix Tapping/Selection
-   By removing the `Stack` and allowing the widget to take actual layout space, taps on the expanded options (now within the widget's bounds) will be correctly detected.
-   Ensure `setState` is called on option selection to update the `_currentLocationMode`.

## Verification
1.  Launch App -> Top left shows Green Circle.
2.  Tap Icon -> Expands right (pushes spacer), showing "公開 | 摯友 | 關閉".
3.  **Visual Check**: No yellow/black overflow stripes.
4.  **Interaction Check**: Tapping "摯友" (on the far right) correctly registers, collapses menu, and changes icon to Green Star.
