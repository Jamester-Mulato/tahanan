# Flutter integration notes

The Flutter project should eventually become a thin client of this API.

## Login

1. Google Sign-In occurs in Flutter.
2. Flutter obtains a Google ID token.
3. Flutter sends:

```http
POST /api/auth/google
Content-Type: application/json
```

```json
{
  "idToken": "<google-id-token>"
}
```

4. Backend returns a Tahanan API JWT.
5. Store the Tahanan JWT securely on the device.
6. Send it on all protected requests.

## Boarding house switcher

Do not store one global role.

Call:

```http
GET /api/me
```

The response will contain the active BH memberships.

Example conceptual result:

```json
{
  "user": {
    "id": "...",
    "email": "person@example.com",
    "displayName": "Person"
  },
  "boardingHouses": [
    {
      "boardingHouseId": "house-a",
      "name": "Green Haven",
      "role": "owner"
    },
    {
      "boardingHouseId": "house-b",
      "name": "Santos Boarding House",
      "role": "tenant"
    }
  ]
}
```

The UI should then offer:

```text
My Boarding Houses

Green Haven
OWNER

Santos Boarding House
TENANT

+ Create Boarding House
+ Join Boarding House
```

## Important

Do not recreate the old Flutter `AppUser.role` model as a global role.

Role belongs to the selected BH membership.
