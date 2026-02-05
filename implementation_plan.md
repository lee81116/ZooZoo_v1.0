# Refine Destination Selection

## Goal
Implement a **"Pin & Drag"** interaction for destination selection.
Currently, searching immediately draws a route. The new flow will allow the user to fine-tune the location by moving the map under a fixed center pin before confirming.

## Current State
-   **Weather**: Implemented.
-   **Friends**: Implemented.
-   **Booking**: Inline sheet implemented.
-   **Search Pinning**: Implemented for Search Bar.

## Proposed Changes

### [MODIFY] [passenger_home_page.dart](file:///c:/Works/WinterProject/ZooZoo_v1.0/zoozoo_v1/lib/features/passenger/home/presentation/pages/passenger_home_page.dart)

#### 1. Standardize Pinning Logic
-   Create a helper method `_startPinningMode(double lat, double lng, String name)`:
    1.  Fly map to target (zoom 16).
    2.  Set `_isPinningMode = true`.
    3.  Set `_pinnedSearchName = name`.

#### 2. Update Triggers
-   **Search**: Update `_handleSearch` to call `_startPinningMode`.
-   **History**: Update `_buildHistoryCard`'s `onTap` to call `_startPinningMode` instead of `_drawNavigationRoute`.
-   **Quick Actions**: Update "Home" and "Company" button callbacks to call `_startPinningMode`.

## Verification
1.  **History**: Tap a history item -> Map flies to location -> Pin appears -> Confirm -> Route draws.
2.  **Quick Action**: Tap "Home" -> Map flies to location -> Pin appears -> Confirm -> Route draws.
