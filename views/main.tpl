<!doctype html>
<html>
<head>
    <title>cmus on {{host}}</title>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" type="text/css" href="/static/kube.min.css"/>
    <link rel="stylesheet" type="text/css" href="/static/fontawsome5/css/fontawesome.min.css"/>
    <link rel="stylesheet" type="text/css" href="/static/fontawsome5/css/solid.min.css"/>
    <style type="text/css">
        html,body { position:relative; height:100%; }
        .wrapper {
            width:100%;
            width:calc(100% - 4em);
            max-width: 1600px;
            margin: 0 auto;
            padding:2em 2em 0 2em;
            height:100%;
            height:calc(100% - 2em);
            display:flex;
            flex-direction:column;
        }
        .player {
            flex-grow:2;
            display:flex;
            align-items:center;
            justify-content:center;
        }
        .controls {
            font-size: 2.2em;
            padding: 1ex 0;
        }
        #album_art {
            align-content:center;
            text-align:center;
        }
        #album_art img {
            width:auto;
            height:auto;
            max-width: 100%;
            max-height: 100%;
        }
        #status,#details {
            position: relative;
            min-height: 2em;
            background-color: #f5f5f5;
            transition: background-image {{app_statusrefresh_f}}ms ease;
            border: 1px solid #e3e3e3;
            -webkit-border-radius: 1ex;
            -moz-border-radius: 1ex;
            border-radius: 1ex;
            -webkit-box-shadow: inset 0 1px 1px rgba(0, 0, 0, 0.05);
            -moz-box-shadow: inset 0 1px 1px rgba(0, 0, 0, 0.05);
            box-shadow: inset 0 1px 1px rgba(0, 0, 0, 0.05);
        }
        #status {
            overflow: hidden;
            padding: 1ex 0;
        }
        #status p {
            display: inline-block;
            margin: 0 1em;
            font-size:1.1em;
            line-height: 1em;
            padding: .9em 0;
        }
        #details {
            overflow: auto;
            padding: 1ex;
        }
        .vol {
            position: absolute;
            bottom: 0;
            right: 1ex;
            font-size: .9em;
            color: #888;
        }
        #result {
            min-height: 2em;
        }
        .btn-group,.status-btn { margin-bottom:.5ex; }
        .btn_act { background: none repeat scroll 0 0 #fff; border: 1px solid #ddd; }
        .st_inact { color:#ddd; }
        .nobr { white-space:nowrap; }
        footer p { margin:0.5em 0; }

        @media only screen and (orientation: landscape) {
            #album_art {
                width:50%;
                margin: 0 2em 1em 0;
            }
        }
        @media only screen and (orientation: portrait) {
            .player{
                flex-flow:column;
            }
            #album_art {
                max-width:100%;
                height:80%;
                margin: 0 0 1em;
                display:flex;
                align-items:center;
                justify-content:center;
            }
        }

        @media only screen and (min-width: 480px) and (max-width: 767px) {
            .controls { font-size: 1.4em; }
        }
        @media only screen and (max-width: 479px) {
            .controls { font-size: 1em; }
            .wrapper {
                width:calc(100% - 1.6em);
                height:calc(100% - 1em);
                padding:.8em .8em .2em;
            }
        }
    </style>
</head>
<body>
<div class="wrapper">

<div class="player">

<div id="album_art"></div>

<div class="interface">
<div id="status"></div>

<div class="controls">

    <span class="btn-group">
        <button class="cmd-btn btn" id="btn-previous" title="Previous"><i class="fas fa-fast-backward"></i></button>
        <button class="cmd-btn btn" id="btn-play" title="Play"><i class="fas fa-play"></i></button>
        <button class="cmd-btn btn" id="btn-pause" title="Pause"><i class="fas fa-pause"></i></button>
        <button class="cmd-btn btn" id="btn-stop" title="Stop"><i class="fas fa-stop"></i></button>
        <button class="cmd-btn btn" id="btn-next" title="Next"><i class="fas fa-fast-forward"></i></button>
    </span>

    <span class="btn-group">
        <button class="cmd-btn btn" id="btn-mute" title="Mute"><i class="fas fa-volume-mute"></i></button>
        <button class="cmd-btn btn" id="btn-reduce" title="Reduce Volume"><i class="fas fa-volume-down"></i></button>
        <button class="cmd-btn btn" id="btn-increase" title="Increase Volume"><i class="fas fa-volume-up"></i></button>
    </span>

    <button class="status-btn btn btn-round" title="Update Status"><i class="fas fa-info"></i></button>

</div>

<code id="details"></code>

<div id="result"></div>

</div>
</div>

<footer>
    <p class="small gray-light"><i class="fas fa-play-circle"></i> This is <code>cmus</code> running on {{host}}.</p>
</footer>

</div>
<script src="/static/zepto.min.js"></script>
<script type="text/javascript">
    //global vars
    var statusRefreshRate = {{app_statusrefresh_f}},
        statusPlayStatus, 
        statusCurFullStatus = {file:null},
        statusTimeOut = null,
        statusLastVolume = null;

    function sec2str(t){
        var d = (Math.floor(t/86400) % 24),
            h = ('0'+Math.floor(t/3600) % 24).slice(-2),
            m = ('0'+Math.floor(t/60)%60).slice(-2),
            s = ('0' + t % 60).slice(-2);
        return (d>0?d+'d ':'')+(h>0?h+':':'')+(m>0?m+':':'')+(t>60?s:s+'s');
    }

    function displayStatus(){
        var response = statusCurFullStatus;
        var tit=[],status=[],details='';
        if (response.tag.artist != null) {
            status.push(response.tag.artist+':');
            tit.push(response.tag.artist+':');
        } else if(response.tag.title != null) {
            status.push('(Unknown Artist):');
            tit.push('(Unknown Artist):');
        }
        if (response.tag.title != null) {
            status.push('<strong>'+response.tag.title+'</strong>');
            tit.push(response.tag.title);
        } else if(response.tag.artist != null) {
            status.push('<strong>(unknown)</strong>');
            tit.push('(unknown)');
        }
        if (response.tag.album != null) {
            var d='';
            if(response.tag.date != null) {d=', '+response.tag.date.substring(0,4)}
                status.push('('+response.tag.album+d+')');
            tit.push('('+response.tag.album+d+')');
        }

        if(tit.length==0) { // if no data so far display filename
            status.push('<em>'+response.file+'</em>');
            tit.push(response.file);
        }

        if(response.duration > 0) {
            status.push('<span class="gray nobr">['+(response.status!=='stopped'?sec2str(response.position)+' / ':'')+sec2str(response.duration)+']</span>');
            tit.push('['+(response.status!=='stopped'?sec2str(response.position)+' / ':'')+sec2str(response.duration)+']');
        }

        if (response.status === 'paused') {
            status.unshift('[paused]');
            tit.unshift('[paused]');
            $('#btn-pause').addClass('btn_act');
        } else {
            $('#btn-pause').removeClass('btn_act');
        }

        status = status.join(' ');

        tit = tit.join(' ');
        window.document.title = tit;


        status='<p'+((response.status==='playing')?'':' class="gray"')+'>'+status+'</p><span class="vol gray">';


        if(response.set.vol_left != null) {
            if(response.set.vol_left == response.set.vol_right && response.set.vol_left  == 0) {
                $('#btn-mute').addClass('btn_act');
                status += 'mute';
            } else {
                $('#btn-mute').removeClass('btn_act');
                status += response.set.vol_left;
                if(response.set.vol_left !== response.set.vol_right) {status += '/'+response.set.vol_right}
            }
        }
        if (response.set.repeat_current === 'true') {status += ' <i onclick="runCommand(\'toggle\',\'repeat_current\');" title="repeat current" class="fas fa-redo-alt">1</i>'}
        else {
            status += ' <i onclick="runCommand(\'toggle\',\'shuffle\');" title="shuffle" class="fas fa-random'+(response.set.shuffle === 'true' ? '' : ' st_inact')+'"></i>';
            status += ' <i onclick="runCommand(\'toggle\',\'repeat\');" title="repeat" class="fas fa-redo-alt'+(response.set.repeat === 'true' ? '' : ' st_inact')+'"></i>';
            if (response.set.play_library === 'true') {
                switch(response.set.aaa_mode) {
                    case 'all':    status +=  ' <i onclick="runCommand(\'toggle\',\'aaa_mode\');" title="all from library" class="fas fa-book"></i>'; break;
                    case 'artist': status +=  ' <i onclick="runCommand(\'toggle\',\'aaa_mode\');" title="artist from library" class="fas fa-portrait"></i>'; break;
                    case 'album':  status +=  ' <i onclick="runCommand(\'toggle\',\'aaa_mode\');" title="album from library" class="fas fa-compact-disc"></i>'; break;
                }
            } else {status += ' <i title="playlist" class="fas fa-file-alt"></i>'}
        }
        status += '</span>';

        var pospc = 100*response.position/response.duration;
        $('div#status').html(status);
        document.querySelector('div#status').style.backgroundImage='linear-gradient(to right, #f5f5f5 0%, #fafafa '+pospc+'%, #cfcfcf '+pospc+'%, #f5f5f5 100%)';


        if(response.status==='playing') { $('#btn-play').addClass('btn_act'); } else { $('#btn-play').removeClass('btn_act'); }


        details = response.file+'<br />';
        details += '<br /><b>Tags</b><br />';
        var i=0;
        var tagorder = [
            'artist',
            'album',
            'date',
            'title',
            'tracknumber',
            'discnumber',
            'replaygain_album_gain',
            'replaygain_album_peak',
            'replaygain_track_gain',
            'replaygain_track_peak'
        ];
        for(i in tagorder) {
            if(typeof(response.tag[tagorder[i]])!=='undefined') {
                details += tagorder[i]+': '+response.tag[tagorder[i]]+'<br />';
            }
        }
        Object.keys(response.tag)
            .sort()
            .forEach(function(k, i) {
                if(tagorder.indexOf(k)<0) {
                    details += k+': '+response.tag[k]+'<br />';
                }
            });
        if('{{show_cmus_settings}}'==='yes') {
            details += '<br /><b>cmus</b><br />';
            for(i in response.set) {
                details += i+': '+response.set[i]+'<br />';
            }
        }
        $('code#details').html(details);
    }

    function runCommand(command,param){
        var dt = {command: command};
        if(command==='Mute') {
            if(parseInt(statusCurFullStatus.set.vol_left,10)+parseInt(statusCurFullStatus.set.vol_right,10)===0) { dt.param = statusLastVolume!==null ? statusLastVolume : '100|100'; command='Unmute'; }
            else { statusLastVolume = statusCurFullStatus.set.vol_left+'|'+statusCurFullStatus.set.vol_right; }
        }
        if(command==='toggle') {
            dt.param = param;
            command += ' ' + param;
        }
        $.ajax({type: 'POST', url: '/cmd', data: dt, context: $("div#result"),
            error: function(response){
                var msg = '<p class="red label"><i class="fas fa-remove"></i> ' + command + '</p>';
                this.html(msg);
            },
            success: function(response){
                var msg = '<p class="green label"><i class="fas fa-check"></i> ' + command + '</p>';
                if (response.output) { msg += '<pre>' + response.output + '</pre>'; }
                this.html(msg);
                updateFullStatus();
            }})
    }

    function updateStatus(){
        $.ajax({url: '/status', dataType: 'json', context: $("div#status"),
            error: function(){
                var msg = '<p class="error">Connection to <code>cmus</code> cannot be established.</p>';
                this.html(msg);
                setTimeout(updateStatus, {{app_statusrefresh_e}});
            }, 
            success: function(response){
                if(statusCurFullStatus.file!==response.file || statusPlayStatus!==response.status) {
                    updateFullStatus();
                } else {
                    statusPlayStatus = response.status;
                    statusCurFullStatus.position = response.position;

                    displayStatus();

                    setStatusRefreshrate();
                    if(statusTimeOut!==null) { clearTimeout(statusTimeOut); }
                    statusTimeOut = setTimeout(updateStatus, statusRefreshRate);
                }
        }})
    }
    function updateFullStatus(){
        $.ajax({url: '/fullstatus', dataType: 'json', context: $("div#status"),
            error: function(){
                var msg = '<p class="error">Connection to <code>cmus</code> cannot be established.</p>';
                this.html(msg);
                setTimeout(updateStatus, {{app_statusrefresh_e}});
            }, 
            success: function(response){
                if(statusCurFullStatus.albumart_file !== response.albumart_file) {
                    $("#album_art").html('<img src="'+(response.albumart_file?'/album_art/'+response.albumart_file:'static/noalbumart.png')+'"/>');
                }
                statusPlayStatus = response.status;
                statusCurFullStatus = response;

                displayStatus();
    
                setStatusRefreshrate();
                if(statusTimeOut!==null) { clearTimeout(statusTimeOut); }
                statusTimeOut = setTimeout(updateStatus,statusRefreshRate);
        }})
    }

    $(".status-btn").on('click', (function() {
        $('code#details').toggle();
        //updateFullStatus();
    }));

    $(".cmd-btn").on('click', (function(){
        var cmd = $(this).attr('title');
        runCommand(cmd);
        updateFullStatus();
    }));

    $("div#result").on('click', (function(){
        $(this).empty()
    }));


    Zepto(function() {
        $('code#details').hide(); //nice2have: store display locally (as well as other settings)
        updateFullStatus();
    });

    // set statusrefresh based on tabvisibility and playstatus
    function setStatusRefreshrate() {
        if(document.visibilityState === 'hidden') { statusRefreshRate = {{app_statusrefresh_o}}; }
        else if(statusPlayStatus === 'stopped') { statusRefreshRate= {{app_statusrefresh_s}}; }
        else { statusRefreshRate = {{app_statusrefresh_f}}; }
    }
    document.addEventListener('visibilitychange', setStatusRefreshrate, false);

    //hide albumart-box if disabled
    if('{{serve_albumart}}'!=='yes') { $("#album_art").hide(); }
</script>
</body>
</html>
