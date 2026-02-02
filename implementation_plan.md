# Add Friend Markers

## Goal
Populateland the map with more friends to enhance the social atmosphere.

## Specifications
Add 3 new friends near the user's location:
1.  **Mr. Brown Bear (棕熊先生)**
    -   Emoji: 🐻
    -   Color: Brown
2.  **Mr. Grey Wolf (灰狼先生)**
    -   Emoji: 🐺
    -   Color: BlueGrey
3.  **Ms. Red Fox (紅狐小姐)**
    -   Emoji: 🦊
    -   Color: DeepOrange

## Proposed Changes

### [MODIFY] [passenger_home_page.dart](file:///c:/Works/WinterProject/ZooZoo_v1.0/zoozoo_v1/lib/features/passenger/home/presentation/pages/passenger_home_page.dart)

#### `_addFriendMarkers`
-   Add the new entries to the `_friends` list.
-   Calculate random offsets (or fixed small offsets) from `centerLat`/`centerLng` so they appear nearby.

## Verification
1.  Launch App.
2.  **Verify**: Map shows 5 friends total (Snow Leopard, Reindeer, Brown Bear, Wolf, Fox).
3.  **Verify**: Clicking them draws a route to their location.
