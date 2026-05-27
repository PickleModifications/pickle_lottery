function InitializeKeno(data) {
    var game = data.game 
    var data = data.data
    let SPOTS = game.prizes

    let SPOT_COUNT = SPOTS.length
    
    let NUM_COUNT = game.ballCount
    
    let WAGERS = game.wagers
    let GAMES = game.games
    
    function StartKeno() {
        $("#app-keno").fadeIn(500)
        $("#app-keno").html(`
            <div id="ak-front">
                <div class="ak-header">
                    <img src="assets/images/banner-keno.png">
                </div>
                <div class="ak-container">
                    <div class="akc-section">
                        <div>Amount of games to play.</div>
                        <div id="akc-section-1"></div>
                    </div>
                    <div class="akc-section">
                        <div>Wager amount for each game.</div>
                        <div id="akc-section-2"></div>
                    </div>
                    <div class="akc-section">
                        <div>Amount of numbers (spots) to play.</div>
                        <div id="akc-section-3"></div>
                    </div>
                    <div class="akc-section">
                        <div>Pick the numbers (spots) to play.</div>
                        <div id="akc-section-4"></div>
                    </div>
                    <div class="akc-submit">
                        <div class="arrow-down"></div>
                        <div>SAVE TICKET</div>
                    </div>
                </div>
            </div>
            <div id="ak-back">
                <div class="ak-header">
                    <h1 class="text-large">KENO PRIZES & RULES</h1>
                </div>
                <div id="akb-prizes">
                </div>
            </div>
        `)

        // BACK KENO
    
        let html = ""
        for (let i=0; i<SPOTS.length; i++) {
            let prizesHtml = "";
            for (j=0; j<SPOTS[i].length; j++) {
                if (SPOTS[i][j] > 0) {
                    prizesHtml += `
                        <div>
                            <div>${j}</div>
                            <div>${GetFormattedCash(SPOTS[i][j])}</div>
                        </div>
                    `;
                }
            } 
            html += `
                <div>
                    <div>${i + 1} SPOT GAME</div>
                    <div>
                        <div>
                            <div>Spots</div>
                            <div>Prize</div>
                        </div>
                        ${prizesHtml}
                    </div>
                </div>
            `;
        }
        $("#akb-prizes").html(html)
        
        // FRONT KENO

        html = ""
        for (let i=0; i < GAMES.length; i++) {
            if (data.games && (data.games - 1) == i) {
                html += `<div class="selected">${GAMES[i]}</div>`
            }
            else {
                html += `<div>${GAMES[i]}</div>`
            }
        }
        $("#akc-section-1").html(html)
    
        html = ""
        for (let i=0; i < WAGERS.length; i++) {
            if (data.wager && (data.wager - 1) == i) {
                html += `<div class="selected">${WAGERS[i]}</div>`
            }
            else {
                html += `<div>${WAGERS[i]}</div>`
            }
        }
        $("#akc-section-2").html(html)
    
        html = ""
        for (let i=1; i <= SPOT_COUNT; i++) {
            if (data.spots && data.spots.length == i) {
                html += `<div class="selected">${i}</div>`
            }
            else {
                html += `<div>${i}</div>`
            }
        }
        $("#akc-section-3").html(html)
    
        html = ""
        for (let i=1; i <= NUM_COUNT; i++) {
            if (data.spots) {
                var selected = false;
                for (let j=0; j < data.spots.length; j++) {
                    if (data.spots[j] == i) {
                        selected = true;
                    }
                }
                if (selected) {
                    html += `<div class="selected">${i}</div>`
                }
                else {
                    html += `<div>${i}</div>`
                }
            }
            else {
                html += `<div>${i}</div>`
            }
        }
        $("#akc-section-4").html(html)
    
        $("#akc-section-1 > div").click(function() {
            ToggleMark(1, $(this))
        })
        $("#akc-section-2 > div").click(function() {
            ToggleMark(2, $(this))
        })
        $("#akc-section-3 > div").click(function() {
            ToggleMark(3, $(this))
        })
        $("#akc-section-4 > div").click(function() {
            ToggleMark(4, $(this))
        })
    }
    
    function GetSelections(sectionIndex) {
        let selections = []
        let options = $("#akc-section-" + sectionIndex).children()
        options.each(function() {
            if ($(this).hasClass("selected")) {
                selections.push($(this).index());
            }
        });
        return selections;
    }
    
    function ToggleMark(sectionIndex, element) {
        if (sectionIndex != 4) {
            if (element.hasClass("selected")) {
                element.removeClass("selected")
            }
            else {
                $("#akc-section-" + sectionIndex).children().removeClass("selected")
                element.addClass("selected")
            }
        }
        else {
            if (element.hasClass("selected")) {
                element.removeClass("selected")
            }
            else {
                let max = GetSelections(3)[0];
                if (max != undefined) {
                    max += 1;
                }
                else {
                    max = 0;
                }
                let count = GetSelections(sectionIndex).length
                if (count < max) {
                    element.addClass("selected")
                }
            }
        }
    }
    
    function SubmitKeno() {
        let errorIndex;
        let errorReason;
        for (let i=1; i<4; i++) {
            if (GetSelections(i)[0] == undefined) {
                errorIndex = i; 
                errorReason = `You need to select an option in field #${i}.`;
                break;
            }
        }
        if (errorIndex == undefined) {
            let required = GetSelections(3)[0] + 1;
            let selections = GetSelections(4).length;
            if (selections < required) {
                errorIndex = 4; 
                errorReason = `You need to select ${required - selections} more spots.`;
            }
            else if (selections > required) {
                errorIndex = 4; 
                errorReason = `You need to remove ${selections - required} spots.`;
            }
        } 
        if (errorIndex != undefined) {
            Notify(errorReason)
        } 
        else {
            let selections = []
            for (let i=1; i<=4; i++) {
                selections.push(GetSelections(i))
            }
            $.post("https://pickle_lottery/saveTicket", JSON.stringify({
                app: "keno",
                selections: selections
            }));
            HideApps();
        }
    }

    StartKeno();
    
    $(".akc-submit").on("click", () => {
        SubmitKeno();
    });    
}