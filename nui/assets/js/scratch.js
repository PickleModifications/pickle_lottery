function InitializeScratch(_data) {
    let data = _data.data
    let WIN_NUMBERS = data.winningNumbers || [0, 0, 0, 0, 0, 0]
    let NUMBERS = data.numbers || [0, 0, 0, 0, 0, 0, 0, 0, 0]
    let PRIZES = data.prizes || [[1, 2], [2, 4], [3, 8], [4, 16], [5, 32], [6, 1000000]]
    
    function StartScratch() {
        $("#app-scratch").fadeIn(500)
        let winHtml = "";
        
        for (let i=0; i<WIN_NUMBERS.length; i++) {
            winHtml += `<div>${DisplayInt(WIN_NUMBERS[i])}</div>`
        }

        let numbersHtml = "";

        for (let i=0; i<NUMBERS.length; i++) {
            numbersHtml += `<div>${DisplayInt(NUMBERS[i])}</div>`
        }

        let prizesHtml = "";
        
        for (let i=0; i<PRIZES.length; i++) {
            prizesHtml += `
                <div>
                    <div>${i + 1}</div>
                    <div>${GetFormattedCash(PRIZES[i])}</div>
                </div>
            `;
        }

        var topStyle = `style="grid-template-columns: repeat(${PRIZES.length},auto);"`
        var bottomStyle = `style="grid-template-columns: repeat(${data.eachRow},auto);"`

        $("#app-scratch").html(`
            <div id="as-front">
                <div class="asf-scratch" ${topStyle}>
                    ${winHtml}
                </div>
                <div class="asf-scratch" ${bottomStyle}>
                    ${numbersHtml}
                </div>
            </div>
            <div id="as-back">
                <div id="asb-prizes">    
                    <div>
                        <div>PRIZES</div>
                        <div>
                            <div>
                                <div>Spots</div>
                                <div>Prize</div>
                            </div>
                            ${prizesHtml}
                        </div>
                    </div>
                </div>
            </div>
        `)

        var canvas = document.getElementById('as-front'),
        image = 'assets/images/' + data.background,
        scratch = 'assets/images/scratch.png',
        revealPercent = 50;
        if(!data.scratched && ScratchIt.isSupported()){
            ScratchIt(canvas, image, scratch, function() {}, revealPercent);
        }
    }
    StartScratch()
}