# Post Deplopyment Steps
1. Assign the OHR_Scheduler_Admin permission group to the relevant users
2. Assign the OHRS Guest Site User Access permission set to the OHRS Site App Guest Site User.
3. Add admins of the RCS app to the OHRS Admins public group so they have access to the email templates available for that app.
4. Update the "OHRS_Site_Base_URL" custom label as follow
- Go to sites and copy the site url
- Go to the custom label mentioned before and add as value [ siteURL ]/s/ohrs-landing-page
So, if the site url is https://Mysiteuspto.gov the custom label should be:
https://Mysiteuspto.gov/s/ohrs-landing-page

5. Make sure to publish the site after the deployment
6. Update email alerts 	"OHRS Appointment Booked References", "OHRS Booking Confirmation for Volunteers", so the sender is the "Do Not Reply" email.

# Once The new flow 'RCS_References_Questionaire_Forms' gets deployed, Give the "OHRS Site App Profile" access to it
1. Go to Setup --> flows 
2. Find 'RCS_References_Questionaire_Forms' flow --> clicked on the dropdown menu on the right --> click on Edit Access --> Enable 'Override default behavior and restrict access to enabled profiles or permission sets' box.
3. Click save
4. Go to the "OHRS Site App Profile" --> Click on "Flow Access" --> CLick on Edit --> Make sure that the  "RCS_References_Questionaire_Forms" is in the "Enabled Flows" section --> Click Save