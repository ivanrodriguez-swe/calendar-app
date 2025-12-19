// --- Configuration: set the date for which to create timeslots ---
Date targetDay = Date.newInstance(2025, 12, 17); // change to the desired date (YYYY, M, D)

// --- Constants for the schedule ---
Time businessStart = Time.newInstance(9, 0, 0, 0);   // 9:00 AM
Time businessEnd   = Time.newInstance(17, 0, 0, 0);  // 5:00 PM
Integer slotMinutes = 20;
Integer defaultAvailable = 5;

// --- Build timeslot records ---
List<time_slot__c> slotsToInsert = new List<time_slot__c>();

Time currentStart = businessStart;
while (currentStart < businessEnd) {
    // compute end time for this slot
    Integer millis = slotMinutes * 60 * 1000;
    Time currentEnd = Time.newInstance(currentStart.hour(), currentStart.minute(), currentStart.second(), currentStart.millisecond()).addMilliseconds(millis);

    // Ensure we do not create a slot that extends beyond businessEnd
    if (currentEnd > businessEnd) {
        currentEnd = businessEnd;
    }


    time_slot__c ts = new time_slot__c();
    ts.start_time__c = currentStart;
    ts.end_time__c = currentEnd;
    ts.day__c = targetDay;
    ts.number_available__c = defaultAvailable;

    slotsToInsert.add(ts);

    // advance to next slot
    currentStart = currentEnd;
}

// Bulk insert (wrapped in try/catch)
try {
    if (!slotsToInsert.isEmpty()) {
        insert slotsToInsert;
        System.debug('Inserted ' + slotsToInsert.size() + ' time_slot__c records for ' + targetDay);
    } else {
        System.debug('No slots to insert.');
    }
} catch (DmlException e) {
    System.debug('Insert failed: ' + e.getMessage());
    for (Integer i = 0; i < e.getNumDml(); i++) {
        System.debug('DML error ' + i + ': ' + e.getDmlMessage(i));
    }
}