# opa-community-assets

## Usage

1. Add the `vapgCommunityFooter` to the `TemplateFooter` section of the Community builder
2. Add the `vapgCommunityBanner` to the `TemplateFooter` section of the Community builder
   1. Ensure that the `vapgCommunityBanner` is the last component in the slot
3. Add the following to the **Settings** > **Advanced** > **Edit Head Markup**

      ````javascript
      <script>
          var oldXHR = window.XMLHttpRequest;

          function newXHR() {
              var realXHR = new oldXHR();
              realXHR.addEventListener("readystatechange", function() {
                  if(realXHR.readyState < 4){
                      cleanupBanners();
                  } else if(realXHR.readyState==4 && realXHR.status==200){
                      moveBanner();
                  }
              }, false);
              return realXHR;
          }
          window.XMLHttpRequest = newXHR;
          
          function cleanupBanners(){
              var banners = document.querySelectorAll('section.usa-banner');
              var count = banners.length;
              if(count > 1){
                  for(var i = 0; i < count - 1; i++){
                      banners[i].remove();
                  }
                  
                  var mainBanner = banners[count-1];
                  var header = mainBanner.querySelector('header.usa-banner__header');
                  header.classList.remove("usa-banner__header--expanded");
                  var content = mainBanner.querySelector('div.usa-banner__content.usa-accordion__content');
                  content.hidden = true;
              }       
          }
          
          function moveBanner(){
              var banner = document.querySelector('c-racms-community-banner');
              if(banner){
                  document.body.insertBefore(banner, document.body.firstChild);
              }	
          }

      </script>
      ````
