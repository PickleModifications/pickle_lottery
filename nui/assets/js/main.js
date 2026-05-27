var CurrentApp;

function DisplayInt(float) {
    let floor = Math.floor(float)
    if (floor < 10) {
        floor = "0" + floor;
    }
    return floor;
}

function Notify(text, style) {
    $.notify(text, {
        style: (style ? style : 'error')
    });
}

function HideApps(event) {
    $("#app-keno").fadeOut(500)
    $("#app-keno").removeClass("flip")
    $("#app-moneyball").fadeOut(500)
    $("#app-moneyball").removeClass("flip")
    $("#app-scratch").fadeOut(500)
    $("#app-scratch").removeClass("flip")
    $("#app-receipt").fadeOut(500)
    if (event) {
        $.post("https://pickle_lottery/closeApp", JSON.stringify({}));
    }
}

function DisplayApp(app, data) {
    HideApps()
    CurrentApp = app
    if (app == "keno") {
        InitializeKeno(data)
    }
    else if (app == "moneyball") {
        InitializeMoneyball(data)
    }
    else if (app == "scratch") {
        InitializeScratch(data)
    }
    else if (app == "receipt") {
        InitializeReceipt(data)
    }
}

function GetFormattedCash(value) {
    const formatter = new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD',
    });
      
    return formatter.format(value)
}

function PlayAudio(name, volume) {
    let audio = new Audio("assets/audio/" + name + '.mp3');
    audio.volume = volume;
	audio.play();
    audio.addEventListener("ended", () => {
        audio.pause();
        audio.remove();
    });
}

$(document).ready(function() {
    $.notify.addStyle('success', {
        html: "<div><span data-notify-text/></div>",
        classes: {
          base: {
            "font-family" : "Arial, Helvetica, sans-serif",
            "white-space": "nowrap",
            "background-color": "#2ecc71",
            "padding": "0.75vw",
            "color": "white",
          },
        }
    });
    $.notify.addStyle('error', {
        html: "<div><span data-notify-text/></div>",
        classes: {
          base: {
            "font-family" : "Arial, Helvetica, sans-serif",
            "white-space": "nowrap",
            "background-color": "#e74c3c",
            "padding": "0.75vw",
            "color": "white",
          },
        }
    });
    $("#lottery-prompt").click(()=> {
        $.post("https://pickle_lottery/interactPrompt", JSON.stringify({}));
    })
});

function FlipApp(app, bool) {
    if (bool != undefined) {
        if (bool) {
            $("#app-" + app).addClass("flip")
        }
        else {
            $("#app-" + app).removeClass("flip")
        }
    }
    else {
        if (!$("#app-" + app).hasClass("flip")) {
            $("#app-" + app).addClass("flip")
        }
        else {
            $("#app-" + app).removeClass("flip")
        }
    }
}

window.addEventListener('keydown', (event) => {
    var name = event.key;
    if (name == " ") {
        FlipApp(CurrentApp)
    }
    else if (name == "Backspace" || name == "Escape") {
        HideApps(true);
    }
}, false);

window.addEventListener('message', function(ev) {
    if (ev.data.type == "displayApp") {
        DisplayApp(ev.data.app, ev.data.data);
    }
    else if (ev.data.type == "hideApp") {
        HideApps(true);
    }
    else if (ev.data.type == "playAudio") {
        PlayAudio(ev.data.name, ev.data.volume);
    }
}) 