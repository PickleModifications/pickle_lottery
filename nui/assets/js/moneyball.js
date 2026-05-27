function InitializeMoneyball(data) {
    var game = data.game 
    var data = data.data
    var MAX_NUM = game.prizes.length || 5
    MAX_NUM = MAX_NUM - 1

    const NUM_COUNT = game.ballCount || 70
    const BALL_COUNT = game.moneyballCount || 28
    const PANEL_COUNT = game.panelCount || 4
    const PRIZES = game.prizes || []
    
    function RegisterMoneyballEvents(index) {
        var index = index
        $("#amc-section-"+index+" > div").click(function() {
            ToggleMoneyballMark("pick", index, $(this))
        })

        $("#amc-ball-"+index+" > div").click(function() {
            ToggleMoneyballMark("ball", index, $(this))
        })
    }

    function StartMoneyball() {
        $("#app-moneyball").fadeIn(500)
        $("#app-moneyball").html(`        
            <div id="am-front">
                <div class="am-header">
                    <img src="assets/images/banner-moneyball.png">
                </div>
                <div class="am-container">
                </div>
            </div>
            <div id="am-back">
                <div class="am-header">
                    <h1 class="text-large">MONEYBALL PRIZES & RULES</h1>
                </div>
                <div id="amb-prizes">
                </div>
            </div>
        `);
        
        let html = ""
        for (let i=0; i<PRIZES.length; i++) {
            var prizeTitle;
            if (i + 1 == PRIZES.length) {
                prizeTitle = `<div>${i} Spots + Moneyball</div>`
            }
            else {
                prizeTitle = `<div>${i + 1} Spots</div>`
            }
            html += `
                <div>
                    ${prizeTitle}
                    <div>${GetFormattedCash(PRIZES[i])}</div>
                </div>
            `;
        }
        $("#amb-prizes").html(`
            <div>
                <div>PRIZES</div>
                <div>
                    <div>
                        <div>Spots</div>
                        <div>Prize</div>
                    </div>
                    ${html}
                </div>
            </div>
        `)
        
        let containerHtml = ""
        for (let i=1; i <= PANEL_COUNT; i++) {
            let html = ""
            for (let j=1; j <= NUM_COUNT; j++) {
                var found = false;
                if (data.panels && data.panels[i-1]) {
                    for (let k=0; k < data.panels[i-1].length - 1; k++) {
                        if (data.panels[i-1][k] == j - 1) {
                            html += `<div class="selected">${j}</div>`
                            found = true;
                            break;
                        }
                    }
                }
                if (!found) {
                    html += `<div>${j}</div>`
                }
            }
    
            let ballHtml = ""
            for (let j=1; j <= BALL_COUNT; j++) {
                if (data.panels && data.panels[i-1] && data.panels[i-1][data.panels[i-1].length - 1] == j - 1) {
                    ballHtml += `<div class="selected">${j}</div>`
                }
                else {
                    ballHtml += `<div>${j}</div>`
                }
            }

            containerHtml += `
                <div class="amc-section">
                    <div>Panel #${i}</div>
                    <div id="amc-section-${i}">${html}</div>
                    <div>Moneyball #${i}</div>
                    <div id="amc-ball-${i}">${ballHtml}</div>
                </div>
            `
        }

        containerHtml += `
            <div class="amc-submit">
                <div class="arrow-down"></div>
                <div>SAVE TICKET</div>
            </div>
        `
        $(".am-container").html(containerHtml);

        for (let i=1; i <= PANEL_COUNT; i++) {
            RegisterMoneyballEvents(i);
        }
        
        $(".amc-submit").on("click", () => {
            SubmitMoneyball();
        });
    }
    
    function GetMoneyballSelections(sectionIndex, includeBall) {
        let selections = []
        let options = $("#amc-section-" + sectionIndex).children()
        options.each(function() {
            if ($(this).hasClass("selected")) {
                selections.push($(this).index());
            }
        });
        if (includeBall) {
            let ballIndex = null;
            let options = $("#amc-ball-" + sectionIndex).children()
            options.each(function() {
                if ($(this).hasClass("selected")) {
                    ballIndex = $(this).index()
                }
            });
            return [selections, ballIndex];
        }
        else {
            return selections
        }
    }
    
    function ToggleMoneyballMark(type, sectionIndex, element) {
        if (type == "ball") {
            if (element.hasClass("selected")) {
                element.removeClass("selected")
            }
            else {
                $("#amc-ball-" + sectionIndex).children().removeClass("selected")
                element.addClass("selected")
            }
        }
        else {
            if (element.hasClass("selected")) {
                element.removeClass("selected")
            }
            else {
                let max = MAX_NUM;
                let count = GetMoneyballSelections(sectionIndex).length
                if (count < max) {
                    element.addClass("selected")
                }
            }
        }
    }
    
    function SubmitMoneyball() {
        let errorIndex;
        let errorReason;
        let panels = [];
        for (let i=1; i<=PANEL_COUNT; i++) {
            let required = MAX_NUM;
            let data = GetMoneyballSelections(i, true);
            let selections = data[0].length;
            let ballIndex = data[1];
            if (selections > 0) {
                if (selections < required) {
                    errorIndex = i; 
                    errorReason = `You need to select ${required - selections} more spots from #${i}.`;
                    break;
                }
                else if (selections > required) {
                    errorIndex = i; 
                    errorReason = `You need to remove ${selections - required} spots from #${i}.`;
                    break;
                }
                if (ballIndex == null) {
                    errorIndex = i; 
                    errorReason = `You need to select a moneyball in #${i}.`;
                    break;
                }
                panels.push(data)
            }
            else if (ballIndex != null) {
                errorIndex = i; 
                errorReason = `You need to select 5 more spots from #${i}.`;
                break;
            }
        }
        if (errorIndex != undefined) {
            Notify(errorReason)
        }
        else if (panels.length < 1) {
            Notify("You haven't filled any panels out.")
        } 
        else {
            Notify("Success!", "success")
            $.post("https://pickle_lottery/saveTicket", JSON.stringify({
                app: "moneyball",
                panels: panels
            }));
            HideApps();
        }
    }

    StartMoneyball();
}