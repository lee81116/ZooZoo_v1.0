# Dynamic 3D Map Route

## Goal
Ensure the **3D Map Ride Simulation** uses the actual Start (User Location) and Destination (Selected Location) chosen by the user, instead of hardcoded defaults.

## Data Flow
1.  **PassengerHomePage**:
    -   User selects Destination (Search/History/Friend).
    -   Stores `_selectedDestLat`, `_selectedDestLng`.
    -   On "Confirm Phone", passes `userLocation` (End for Driver) and `destinationLocation` (End for Ride) to `Routes.passengerBooking`.
2.  **BookingMapPage (Waiting)**:
    -   Accepts `userLocation` and `destinationLocation`.
    -   Simulates Driver -> User (Start: Random, End: `userLocation`).
    -   On Arrival, passes `userLocation` (Start for Ride) and `destinationLocation` (End for Ride) to `Routes.passenger3DMap`.
3.  **Passenger3DMapPage**:
    -   Accepts `startLocation` and `endLocation`.
    -   Simulates Ride: `startLocation` -> `endLocation`.

## Proposed Changes

### [MODIFY] [app_router.dart](file:///c:/Works/WinterProject/ZooZoo_v1.0/zoozoo_v1/lib/app/router/app_router.dart)
-   Update `passengerBooking` route to parse `extra` arguments:
    -   `userLocation` (AppLatLng)
    -   `destinationLocation` (AppLatLng)
    -   `vehicleType` (String)
    -   `price` (int)

### [MODIFY] [passenger_home_page.dart](file:///c:/Works/WinterProject/ZooZoo_v1.0/zoozoo_v1/lib/features/passenger/home/presentation/pages/passenger_home_page.dart)
-   In `_showVehicleSelectionSheet` -> `onTap`:
    -   Construct `extra` map with `lat`/`lng` of destination and user.
    -   Call `context.push(Routes.passengerBooking, extra: {...})`.

### [MODIFY] [booking_map_page.dart](file:///c:/Works/WinterProject/ZooZoo_v1.0/zoozoo_v1/lib/features/passenger/booking/presentation/pages/booking_map_page.dart)
-   Add constructor arguments for locations and vehicle info.
-   Use `userLocation` property instead of hardcoded `_userLat`/`_userLng`.
-   In `_onDriverArrived`:
    -   Pass `startLocation: widget.userLocation` and `endLocation: widget.destinationLocation` to `Routes.passenger3DMap`.

### [MODIFY] [passenger_3d_map_page.dart](file:///c:/Works/WinterProject/ZooZoo_v1.0/zoozoo_v1/lib/features/passenger/home/presentation/pages/passenger_3d_map_page.dart)
-   (Ideally already set up, but verify `_fetchRoute` uses `_startLocation`/`_endLocation`).

## Verification
1.  Select a specific destination (e.g., Friend).
2.  Confirm booking.
3.  Wait for driver (Driver -> You).
4.  Simulation starts (You -> Friend).
5.  Verify the path matches the real locations.
