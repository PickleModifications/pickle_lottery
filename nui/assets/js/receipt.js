function GetReceiptHtml(data) {
    if (data.game == "keno") {
        let spotsHtml = ""

        for (let i=0; i<data.spots.length; i++) {
            spotsHtml += `<div>${DisplayInt(data.spots[i])}</div>`
        }
        return `
        <div class="ar-header">
            <img src="assets/images/banner-${data.game}.png">
        </div>
        <div class="ar-container">
            <div class="arc-row centered">
                <div>${data.spots.length} SPOTS $${data.wager}.00 DRAW</div>
            </div>
            <div class="arc-spots">
                ${spotsHtml}
            </div>
            <div class="arc-row centered">
                <div>${data.date}</div>
            </div>
            <div class="arc-row">
                <div>${data.games} DRAWS</div>
                <div>${data.gameStart == data.gameEnd ? ("GAME #" + data.gameStart) : ("GAMES #" + data.gameStart + "-#" + data.gameEnd)}</div>
            </div>
            <div class="arc-row">
                <div>PRICE: $${data.wager * data.games}.00</div>
            </div>
            <div class="arc-barcode">
                <img src="assets/images/barcode.png">
            </div>
        </div>
        `
    }
    else if (data.game == "moneyball") {
        let entriesHtml = ""
    
        for (let i=0; i<data.panels.length; i++) {
            entriesHtml += `<div><div>#${i + 1}</div>`
            for (let j=0; j<data.panels[i].length; j++) {
                if (j + 1 == data.panels[i].length) {
                    entriesHtml += `<div class="receipt-red">${DisplayInt(data.panels[i][j] + 1)}</div>`
                }
                else {
                    entriesHtml += `<div>${DisplayInt(data.panels[i][j] + 1)}</div>`
                }
            }
            entriesHtml += `</div>`
        }
        return `
        <div class="ar-header">
            <img src="assets/images/banner-${data.game}.png">
        </div>
        <div class="ar-container">
            <div class="arc-row centered">
                <div>${data.panels.length} ENTRIES</div>
            </div>
            <div class="arc-spots moneyball">
                ${entriesHtml}
            </div>
            <div class="arc-row centered">
                <div>${data.date}</div>
            </div>
            <div class="arc-row">
                <div>PRICE: $${data.price * data.panels.length}.00</div>
                <div>GAME #${data.gameStart}</div>
            </div>
            <div class="arc-barcode">
                <img src="assets/images/barcode.png">
            </div>
        </div>
        `
    }
}

function InitializeReceipt(data) {
    let html = GetReceiptHtml(data.data)
    $("#app-receipt").html(html);
    $("#app-receipt").fadeIn(500);
}