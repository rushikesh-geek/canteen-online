# Auto Cut-off Logic (Pseudocode)

## Overview
Prevents system overload by stopping order acceptance at slot level and global kitchen level.

---

## Cut-off Levels

1. **Slot-level Cut-off**: Individual time slots reach capacity
2. **Global Kitchen Cut-off**: Overall kitchen capacity exceeded
3. **Manual Cut-off**: Admin emergency override

---

## Algorithm 1: Slot-Level Cut-off

```pseudocode
FUNCTION checkSlotCutoff(slotId)
  
  slot = getSlot(slotId)
  
  // RULE 1: Slot is full
  IF slot.currentCount >= slot.maxCapacity THEN
    slot.status = "full"
    slot.autoClosedAt = currentTime
    updateSlot(slot)
    
    RETURN {
      isOpen: false,
      reason: "SLOT_FULL",
      message: "This time slot is full. Please select a different pickup time."
    }
  END IF
  
  
  // RULE 2: Slot is in the past
  IF slot.startTime < currentTime THEN
    slot.status = "closed"
    updateSlot(slot)
    
    RETURN {
      isOpen: false,
      reason: "SLOT_EXPIRED",
      message: "This time slot has passed. Please select an upcoming time."
    }
  END IF
  
  
  // RULE 3: Slot is too soon (buffer time)
  // TODO: Define buffer time (e.g., 15 minutes before slot starts)
  bufferTimeMinutes = 15  // Configurable constant
  cutoffTime = slot.startTime - bufferTimeMinutes
  
  IF currentTime > cutoffTime THEN
    slot.status = "closed"
    updateSlot(slot)
    
    RETURN {
      isOpen: false,
      reason: "SLOT_TOO_SOON",
      message: "Too close to pickup time. Please select a later slot."
    }
  END IF
  
  
  // RULE 4: Slot is manually closed by admin
  IF slot.status == "closed" AND slot.manuallyClosedBy != NULL THEN
    RETURN {
      isOpen: false,
      reason: "MANUALLY_CLOSED",
      message: "Orders temporarily paused for this slot. Please try another time."
    }
  END IF
  
  
  // Slot is open and accepting orders
  RETURN {
    isOpen: true,
    reason: "AVAILABLE",
    message: "Slot available"
  }
  
END FUNCTION
```

---

## Algorithm 2: Global Kitchen Cut-off

```pseudocode
FUNCTION checkGlobalKitchenCutoff()
  
  // RULE 1: Check active order count
  // Count all orders with status "pending" or "preparing"
  activeOrders = countOrders(status IN ["pending", "preparing"])
  
  // TODO: Define max concurrent orders kitchen can handle
  maxConcurrentOrders = 100  // Configurable constant
  
  IF activeOrders >= maxConcurrentOrders THEN
    RETURN {
      isOpen: false,
      reason: "KITCHEN_OVERLOADED",
      message: "Kitchen at full capacity. Please try again in 10-15 minutes.",
      retryAfterMinutes: 15
    }
  END IF
  
  
  // RULE 2: Check if kitchen is operating
  // TODO: Define canteen operating hours
  canteenOpenTime = "08:00"    // 8 AM
  canteenCloseTime = "17:00"   // 5 PM
  lastOrderTime = "16:30"      // Stop accepting 30 mins before close
  
  currentHourMinute = formatTime(currentTime, "HH:mm")
  
  IF currentHourMinute < canteenOpenTime THEN
    RETURN {
      isOpen: false,
      reason: "NOT_OPEN_YET",
      message: "Canteen opens at " + canteenOpenTime + ". Come back soon!"
    }
  END IF
  
  IF currentHourMinute >= lastOrderTime THEN
    RETURN {
      isOpen: false,
      reason: "CLOSED_FOR_DAY",
      message: "Order placement closed for today. We reopen at " + canteenOpenTime + " tomorrow."
    }
  END IF
  
  
  // RULE 3: Check slot availability for today
  // If no slots are available for rest of the day, stop accepting orders
  openSlots = countSlots(date = TODAY, status = "open", startTime > currentTime)
  
  IF openSlots == 0 THEN
    RETURN {
      isOpen: false,
      reason: "NO_SLOTS_REMAINING",
      message: "All pickup slots for today are full. Please try again tomorrow."
    }
  END IF
  
  
  // RULE 4: Manual emergency cut-off by admin
  globalSettings = getGlobalSettings()
  
  IF globalSettings.orderingPaused == true THEN
    pausedBy = globalSettings.pausedByAdminId
    pauseReason = globalSettings.pauseReason || "Temporary maintenance"
    
    RETURN {
      isOpen: false,
      reason: "ADMIN_PAUSED",
      message: pauseReason,
      pausedBy: pausedBy,
      pausedAt: globalSettings.pausedAt
    }
  END IF
  
  
  // RULE 5: Peak hour surge protection (optional)
  // TODO: Define if we need rate limiting during lunch rush
  // Example: Limit orders to 5 per minute during 12:00-13:00
  // This would require a time-windowed counter
  
  
  // Kitchen is open and accepting orders
  RETURN {
    isOpen: true,
    reason: "AVAILABLE",
    message: "Kitchen accepting orders"
  }
  
END FUNCTION
```

---

## Algorithm 3: Combined Pre-order Validation

```pseudocode
FUNCTION canAcceptNewOrder(preferredSlotId)
  
  // STEP 1: Check global kitchen status first
  kitchenStatus = checkGlobalKitchenCutoff()
  
  IF kitchenStatus.isOpen == false THEN
    RETURN {
      canAccept: false,
      error: kitchenStatus
    }
  END IF
  
  
  // STEP 2: If user specified a slot, check that slot
  IF preferredSlotId is provided THEN
    slotStatus = checkSlotCutoff(preferredSlotId)
    
    IF slotStatus.isOpen == false THEN
      RETURN {
        canAccept: false,
        error: slotStatus
      }
    END IF
  ELSE
    // STEP 3: Check if ANY slots are available
    anyOpenSlot = findNextAvailableSlot()
    
    IF anyOpenSlot is NULL THEN
      RETURN {
        canAccept: false,
        error: {
          reason: "NO_AVAILABLE_SLOTS",
          message: "All slots are currently full. Please try again later."
        }
      }
    END IF
  END IF
  
  
  // All checks passed
  RETURN {
    canAccept: true,
    message: "Ready to accept order"
  }
  
END FUNCTION
```

---

## Algorithm 4: Auto Re-opening Logic (Slot Recovery)

```pseudocode
FUNCTION handleOrderCancellation(orderId)
  
  order = getOrder(orderId)
  slot = getSlot(order.slotId)
  
  // Decrement slot count
  BEGIN_TRANSACTION
    
    slot.currentCount = slot.currentCount - 1
    
    // Auto-reopen slot if it was full
    IF slot.status == "full" AND slot.currentCount < slot.maxCapacity THEN
      slot.status = "open"
      slot.autoClosedAt = NULL
      
      // TODO: Should we notify waiting users that slot reopened?
      // Could trigger FCM notification to users who got "SLOT_FULL" error
    END IF
    
    // Update order status
    order.status = "cancelled"
    order.cancellationReason = "User cancelled"  // Or from input
    
    updateSlot(slot)
    updateOrder(order)
    
  COMMIT_TRANSACTION
  
  RETURN {
    success: true,
    message: "Order cancelled successfully"
  }
  
END FUNCTION
```

---

## Algorithm 5: Manual Cut-off Control (Admin)

```pseudocode
FUNCTION pauseAllOrders(adminUserId, reason)
  
  // Verify admin role
  admin = getUser(adminUserId)
  IF admin.role != "admin" THEN
    RETURN {
      success: false,
      error: "UNAUTHORIZED",
      message: "Only admins can pause ordering"
    }
  END IF
  
  
  // Set global pause flag
  globalSettings = getGlobalSettings()
  globalSettings.orderingPaused = true
  globalSettings.pausedByAdminId = adminUserId
  globalSettings.pauseReason = reason
  globalSettings.pausedAt = currentTime
  
  saveGlobalSettings(globalSettings)
  
  
  // TODO: Send FCM notification to all active users
  // "Ordering temporarily paused: [reason]"
  
  
  RETURN {
    success: true,
    message: "All ordering paused successfully"
  }
  
END FUNCTION


FUNCTION resumeAllOrders(adminUserId)
  
  admin = getUser(adminUserId)
  IF admin.role != "admin" THEN
    RETURN {
      success: false,
      error: "UNAUTHORIZED"
    }
  END IF
  
  
  globalSettings = getGlobalSettings()
  globalSettings.orderingPaused = false
  globalSettings.pausedByAdminId = NULL
  globalSettings.pauseReason = NULL
  globalSettings.resumedAt = currentTime
  
  saveGlobalSettings(globalSettings)
  
  
  // TODO: Send FCM notification
  // "Ordering resumed! Place your orders now."
  
  
  RETURN {
    success: true,
    message: "Ordering resumed successfully"
  }
  
END FUNCTION
```

---

## Configuration Constants (Business Rules)

```pseudocode
// These should be configurable, not hardcoded
CONSTANTS = {
  
  // Slot rules
  slotBufferTimeMinutes: 15,        // Stop accepting orders X mins before slot starts
  slotDurationMinutes: 30,          // How long each slot lasts
  
  // Kitchen capacity
  maxConcurrentOrders: 100,         // Max orders kitchen can handle at once
  maxOrdersPerSlot: 20,             // Max orders per individual slot
  
  // Operating hours
  canteenOpenTime: "08:00",
  canteenCloseTime: "17:00",
  lastOrderAcceptanceTime: "16:30", // Stop accepting 30 mins before close
  
  // Peak hour rules (TODO: Define if needed)
  peakHourStart: "12:00",
  peakHourEnd: "13:00",
  peakHourRateLimit: NULL,          // Not implemented yet
  
  // Recovery
  notifyOnSlotReopening: false      // TODO: Should we notify users?
}
```

---

## User-Facing Error Messages Summary

| Reason | Message |
|--------|---------|
| SLOT_FULL | "This time slot is full. Please select a different pickup time." |
| SLOT_EXPIRED | "This time slot has passed. Please select an upcoming time." |
| SLOT_TOO_SOON | "Too close to pickup time. Please select a later slot." |
| MANUALLY_CLOSED | "Orders temporarily paused for this slot. Please try another time." |
| KITCHEN_OVERLOADED | "Kitchen at full capacity. Please try again in 10-15 minutes." |
| NOT_OPEN_YET | "Canteen opens at 08:00. Come back soon!" |
| CLOSED_FOR_DAY | "Order placement closed for today. We reopen at 08:00 tomorrow." |
| NO_SLOTS_REMAINING | "All pickup slots for today are full. Please try again tomorrow." |
| ADMIN_PAUSED | [Custom admin reason] |
| NO_AVAILABLE_SLOTS | "All slots are currently full. Please try again later." |

---

## Edge Cases Handled

1. **Slot fills during order submission** → Caught by transaction in slot assignment
2. **Orders cancelled** → Auto-reopen slot if below capacity
3. **Admin emergency** → Manual pause/resume with custom messages
4. **Operating hours** → Time-based automatic cut-off
5. **Buffer time** → Prevent last-minute orders that can't be prepared

---

## Edge Cases NOT Handled (TODO)

1. **Partial slot capacity** - What if slot has 1 space left but user orders for 2 people?
2. **VIP/Priority orders** - Should admin/staff have bypass privileges?
3. **Scheduled maintenance** - Auto-pause during specific time windows?
4. **Holiday schedules** - Different hours on weekends/holidays?
5. **Rate limiting** - Prevent single user from spamming orders?
6. **Waitlist feature** - Allow users to join queue when slots are full?

---

## Firestore Schema Addition Needed

```javascript
// New collection: globalSettings (single document)
{
  orderingPaused: boolean,
  pausedByAdminId: string | null,
  pauseReason: string | null,
  pausedAt: timestamp | null,
  resumedAt: timestamp | null,
  
  // Operating hours (can be updated by admin)
  canteenOpenTime: string,      // "08:00"
  canteenCloseTime: string,     // "17:00"
  lastOrderTime: string,        // "16:30"
  
  // Capacity settings
  maxConcurrentOrders: number,
  maxOrdersPerSlot: number,
  slotBufferTimeMinutes: number
}
```

---

## Assumptions

1. All cut-off rules are deterministic and time-based (no predictions)
2. Cut-off decisions are made at order submission time, not slot creation time
3. Cancelled orders immediately free up slot capacity
4. Operating hours are same every day (TODO: Add support for variable schedules)
5. Kitchen capacity is constant (TODO: Add support for dynamic capacity based on staff count)
