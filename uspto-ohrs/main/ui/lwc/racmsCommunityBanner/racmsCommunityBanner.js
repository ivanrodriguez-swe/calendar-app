import { LightningElement } from "lwc";

import RACMS_GOVERNMENT_BANNER_ASSETS from "@salesforce/resourceUrl/RACMS_CommunityBannerAssets";

export default class racmsCommunityBanner extends LightningElement {
  showGuidance = false;

  // =============================================================================
  //
  //  ICON GETTERS
  //
  //===============================================================================
  get buildingIcon() {
    return RACMS_GOVERNMENT_BANNER_ASSETS + "/images/RACMS_Building_Icon.svg";
  }

  get chevronIcon() {
    return this.showGuidance ? "utility:chevronup" : "utility:chevrondown";
  }

  get flagIcon() {
    return RACMS_GOVERNMENT_BANNER_ASSETS + "/images/RACMS_Banner_US_Flag.png";
  }

  get lockIcon() {
    return RACMS_GOVERNMENT_BANNER_ASSETS + "/images/RACMS_Lock_Icon.svg";
  }

  handleToggleClick() {
    this.showGuidance = !this.showGuidance;
  }
}
