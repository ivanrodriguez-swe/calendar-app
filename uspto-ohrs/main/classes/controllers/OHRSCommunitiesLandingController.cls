/**
 * An apex page controller that takes the user to the right start page based on credentials or lack thereof
 */
public with sharing class OHRSCommunitiesLandingController {
    
    // Code we will invoke on page load.
    public PageReference forwardToStartPage() {
        return Network.communitiesLanding();
    }
    
    public OHRSCommunitiesLandingController() {}
}