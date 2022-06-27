window.onload = () => {
    const blendFileInput = document.getElementById("blend_file");
    blendFileInput.addEventListener("change", (event) => showFileName(event));
    window.addEventListener("click", (event) => onButtonClick(event));
    updateCarousel();

    function showFileName(event) {
        const infoArea = document.getElementById("blend_file_name");

        const input = event.srcElement;
        const fileName = input.files[0].name;

        infoArea.textContent = `File chosen: ${fileName}`;
    }

    function badge(state) {
      return {
        "": "warning",
        "Unknown": "warning",
        "Not Started": "warning",
        "Running": "success",
        "Queued": "info",
        "Completed": "primary"
      }[state];
    }

    function updateCarousel() {
        const opts = {
          follow: true,
          headers: {
            'Accept': 'application/json'
          }
        };
    
        const configEle = document.getElementById('job_config');
        const directory = configEle.getAttribute('data-directory');

        const frameRenderjobId = configEle.getAttribute("frame-render-job-id");
        if (frameRenderjobId != null && frameRenderjobId.length > 0) {
        fetch(`/pun/dev/blender/api/job_state/${frameRenderjobId}`, opts)
          .then(response => response.json())
          .then(response => response["job_state"])
          .then(jobState => {
            const frameRenderJobEle = document.getElementById("frame_render_job");
            frameRenderJobEle.innerHTML = jobState;
            frameRenderJobEle.classList.remove(frameRenderJobEle.classList.item(2));
            frameRenderJobEle.classList.add(`badge-${badge(jobState)}`);
          });
        }

        const videoRenderjobId = configEle.getAttribute("video-render-job-id");
        if (videoRenderjobId != null && videoRenderjobId.length > 0) {
        fetch(`/pun/dev/blender/api/job_state/${videoRenderjobId}`, opts)
          .then(response => response.json())
          .then(response => response["job_state"])
          .then(jobState => {
            const videoRenderJobEle = document.getElementById("video_render_job");
            videoRenderJobEle.innerHTML = jobState;
            videoRenderJobEle.classList.remove(videoRenderJobEle.classList.item(2));
            videoRenderJobEle.classList.add(`badge-${badge(jobState)}`);
          });
        }

        fetch(`/pun/sys/files/api/v1/fs/${directory}`, opts)
          .then(response => response.json())
          .then(data => data['files'])
          .then(files => files.map(file => file['name']))
          .then(files => files.filter(file => file.endsWith('png')))
          .then(files => {
            for(const file of files) {
              const id = `image_${file.replaceAll('.', '_')}`;
              const ele = document.getElementById(id);
    
              if(ele == null) {
                console.log(`adding ${file} to carousel`);
    
                const carousel = document.getElementById('blend_image_carousel_inner');
                const carouselList = document.getElementById('blend_image_carousel_indicators');
                const listSize = carouselList.children.length;
    
                const newImg = document.createElement('div')
                newImg.id = id;
                newImg.classList.add('carousel-item');
                newImg.innerHTML = `<img class="d-block w-100" src="/pun/sys/files/api/v1/fs/${directory}/${file}" >`;
    
                const newIndicator = document.createElement('li');
                newIndicator.setAttribute('data-target', '#blend_image_carousel');
                newIndicator.setAttribute('data-slide-to', listSize+1);
    
                const listSpan = document.getElementById('list_size');
                listSpan.innerHTML = `${listSize+1}`;
    
                if(listSize == 0) {
                  newImg.classList.add('active');
                  newIndicator.classList.add('active');
                }
    
                carousel.append(newImg);
                carouselList.append(newIndicator);
              }
            }
          });
    
        setTimeout(updateCarousel, 5000);
    }

    function onButtonClick(event) {
      if (event.srcElement.id == "download-btn") {
        let downloadUrl = `https://ondemand.osc.edu/pun/sys/dashboard/files/fs//users/PZS1127/krish45732/ondemand/dev/blender/projects/${window.location.href.split("/projects/")[1]}/video.mp4?download=${Date.now().toString()}`,
            iframe = document.createElement('iframe'),
            TIME = 30 * 1000;
      
        iframe.setAttribute('class', 'd-none');
        iframe.setAttribute('src', downloadUrl);
      
        document.body.appendChild(iframe);
      
        setTimeout(function() {
          document.body.removeChild(iframe);
        }, TIME);
      }
    };
};