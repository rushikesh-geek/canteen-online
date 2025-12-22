# Smart Order Slotting Logic (Pseudocode)

## Overview
Assigns incoming orders to time-based pickup slots with automatic overflow handling.

---

## Algorithm: Assign Order to Slot

```pseudocode
FUNCTION assignOrderToSlot(userId, orderItems, preferredSlotTime)
  
  // STEP 1: Get available slots for today
  // Fetch all slots where date = TODAY and status != "closed"
  // Sort by startTime in ascending order
  availableSlots = getAllOpenSlotsForToday()
  
  // EDGE CASE: No slots exist for today
  IF availableSlots is empty THEN
    RETURN {
      success: false,
      error: "NO_SLOTS_AVAILABLE",
      message: "No pickup slots available today. Please try again later."
    }
  END IF
  
  
  // STEP 2: Determine target slot
  // If user specified a preferred time, start from that slot
  // Otherwise, start from the next upcoming slot
  IF preferredSlotTime is provided THEN
    targetSlot = findSlotByTime(availableSlots, preferredSlotTime)
    
    // EDGE CASE: User requested slot in the past
    IF targetSlot.startTime < currentTime THEN
      targetSlot = getNextUpcomingSlot(availableSlots)
    END IF
  ELSE
    // Auto-assign to next available slot
    targetSlot = getNextUpcomingSlot(availableSlots)
  END IF
  
  
  // STEP 3: Check capacity and find available slot
  assignedSlot = NULL
  
  // Start from targetSlot and iterate through remaining slots
  FOR each slot in availableSlots starting from targetSlot DO
    
    // Check if slot has capacity
    IF slot.currentCount < slot.maxCapacity THEN
      assignedSlot = slot
      BREAK  // Found available slot, stop searching
    END IF
    
  END FOR
  
  
  // EDGE CASE: All slots are full
  IF assignedSlot is NULL THEN
    RETURN {
      success: false,
      error: "ALL_SLOTS_FULL",
      message: "All pickup slots are full. Please try again later or contact canteen."
    }
  END IF
  
  
  // STEP 4: Create order with assigned slot
  // This is a placeholder - actual DB transaction happens elsewhere
  newOrder = {
    userId: userId,
    items: orderItems,
    slotId: assignedSlot.slotId,
    estimatedPickupTime: assignedSlot.startTime,
    status: "pending",
    placedAt: currentTime
  }
  
  
  // STEP 5: Atomically increment slot count
  // CRITICAL: This must be a transaction to prevent race conditions
  // Multiple orders happening simultaneously could exceed capacity otherwise
  BEGIN_TRANSACTION
    
    // Re-check capacity inside transaction (double-check pattern)
    freshSlot = getSlot(assignedSlot.slotId)
    
    IF freshSlot.currentCount >= freshSlot.maxCapacity THEN
      ROLLBACK_TRANSACTION
      
      // Retry logic - try next slot
      // TODO: Define max retry attempts to prevent infinite loops
      RETURN assignOrderToSlot(userId, orderItems, getNextSlotTime(assignedSlot))
    END IF
    
    // Increment slot counter
    freshSlot.currentCount = freshSlot.currentCount + 1
    
    // Auto-close slot if it reached capacity
    IF freshSlot.currentCount >= freshSlot.maxCapacity THEN
      freshSlot.status = "full"
      freshSlot.autoClosedAt = currentTime
    END IF
    
    // Save order and updated slot
    saveOrder(newOrder)
    updateSlot(freshSlot)
    
  COMMIT_TRANSACTION
  
  
  // STEP 6: Return success response
  RETURN {
    success: true,
    orderId: newOrder.orderId,
    slotId: assignedSlot.slotId,
    estimatedPickupTime: assignedSlot.startTime,
    message: "Order placed successfully. Pickup at " + formatTime(assignedSlot.startTime)
  }
  
END FUNCTION
```

---

## Helper Functions

```pseudocode
FUNCTION getAllOpenSlotsForToday()
  // Get all slots where:
  // - date = TODAY
  // - status = "open" OR (status = "full" but might have cancellations)
  // - startTime > currentTime (no past slots)
  // Sort by startTime ascending
  
  // TODO: Define if "full" slots should be included
  // (they could have capacity if orders get cancelled)
  RETURN slots
END FUNCTION


FUNCTION getNextUpcomingSlot(slots)
  // Return first slot where startTime > currentTime
  FOR each slot in slots DO
    IF slot.startTime > currentTime THEN
      RETURN slot
    END IF
  END FOR
  
  RETURN NULL  // No upcoming slots
END FUNCTION


FUNCTION findSlotByTime(slots, preferredTime)
  // Find slot that contains the preferred time
  FOR each slot in slots DO
    IF slot.startTime <= preferredTime AND slot.endTime > preferredTime THEN
      RETURN slot
    END IF
  END FOR
  
  // Fallback: return closest slot after preferred time
  RETURN getNextUpcomingSlot(slots)
END FUNCTION
```

---

## Edge Cases Handled

1. **No slots exist** → Clear error message
2. **User requests past slot** → Auto-assign to next upcoming slot
3. **All slots full** → Fail with retry suggestion
4. **Race condition** → Transaction with double-check pattern
5. **Slot fills during assignment** → Retry with next slot
6. **Last slot of day is full** → Return "ALL_SLOTS_FULL" error

---

## Edge Cases NOT Handled (TODO)

1. **Max retry attempts** - Currently could retry infinitely if slots keep filling
2. **Slot cancellations** - Should "full" slots become available if orders are cancelled?
3. **Multi-day slots** - What if user wants to order for tomorrow?
4. **Slot buffer time** - Should we stop accepting orders X minutes before slot starts?
5. **Simultaneous large batches** - If 50 orders come at once, how to prevent overload?

---

## Performance Considerations

- **Transaction overhead**: Each order triggers a transaction
- **Query efficiency**: Need index on (date, status, startTime)
- **Real-time updates**: Slot status changes should trigger UI updates for all users
- **Lock contention**: High traffic times may cause transaction retries

---

## Assumptions

1. Slots are pre-generated (by admin or cron job)
2. Each order occupies exactly 1 slot unit (no "order complexity" weighting)
3. Slot capacity is uniform (all slots have same maxCapacity) - TODO: Verify this assumption
4. Users cannot reserve future slots without placing an order
5. Cancelling an order decrements slot.currentCount
