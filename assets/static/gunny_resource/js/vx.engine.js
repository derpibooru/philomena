/*!
  * The GUNNY Engine (https://voltexpixel.com/p/thegunnyengine)
  * Created by Voltex Pixel (https://voltexpixel.com/)
  * Version: dev_20200620
  */
jQuery.loadScript = function (url, callback) {
    jQuery.ajax({
        url: url,
        dataType: 'script',
        success: callback,
        async: true
    });
}

function _gunny() {
	
}

function _gunnyURL(g_url) {
	window.open(g_url, '_blank');
}

function _gunnyRedirect(g_url) {
	window.open(g_url, '_self');
}

function _elementId(g_id) {
	return document.getElementById(g_id);
}

function _gunnyElementId(g_id) {
	return document.getElementById('gunny_u_' + g_id);
}

function _gunnyElementNavId(g_id) {
	return document.getElementById('gunny_u_nav_' + g_id);
}

function _gunnyNavId(g_id) {
	return 'gunny_u_nav_' + g_id;
}

function _gunnyElementHead() {
	return document.head;
}

function _gunnyElementApp() {
	return document.getElementsByTagName("HTML")[0];
}


function str_ireplace(search, replace, subject) {
    var i, k = '';
    var searchl = 0;
    var reg;

    var escapeRegex = function (s) {
        return s.replace(/([\\\^\$*+\[\]?{}.=!:(|)])/g, '\\$1');
    };

    search += '';
    searchl = search.length;
    if (Object.prototype.toString.call(replace) !== '[object Array]') {
        replace = [replace];
        if (Object.prototype.toString.call(search) === '[object Array]') {
            while (searchl > replace.length) {
                replace[replace.length] = replace[0];
            }
        }
    }

    if (Object.prototype.toString.call(search) !== '[object Array]') {
        search = [search];
    }
    while (search.length > replace.length) {
        replace[replace.length] = '';
    }

    if (Object.prototype.toString.call(subject) === '[object Array]') {
        for (k in subject) {
            if (subject.hasOwnProperty(k)) {
                subject[k] = str_ireplace(search, replace, subject[k]);
            }
        }
        return subject;
    }

    searchl = search.length;
    for (i = 0; i < searchl; i++) {
        reg = new RegExp(escapeRegex(search[i]), 'gi');
        subject = subject.replace(reg, replace[i]);
    }

    return subject;
}



function gunny_modalOpen(g_title, g_body, g_footer) {
	document.getElementById('gunny_modal_title').innerHTML = g_title;
	document.getElementById('gunny_modal_body').innerHTML = g_body;
	document.getElementById('gunny_modal_footer').innerHTML = g_footer;
	$('#TheGUNNYEngine').modal('show');
}

function gunny_navAdd(g_id, g_name) {
	document.getElementById('gunny_navigator_list').innerHTML = document.getElementById('gunny_navigator_list').innerHTML + '<li class="sidebar-nav-item" id="' + _gunnyNavId(g_id) + '"><a class="js-scroll-trigger" href="javascript:_gunny()">' + g_name + '</a></li>';
}

function gunny_navEdit(g_id, g_name) {
	document.getElementById(_gunnyNavId(g_id)).innerHTML = '<a class="js-scroll-trigger" href="javascript:_gunny()">' + g_name + '</a>';
}

function gunny_navDelete(g_id) {
	document.getElementById(_gunnyNavId(g_id)).innerHTML = '';
}

function gunny_navAddAction(g_id, g_function) {
	_gunnyElementNavId(g_id).addEventListener("click", g_function);;
}

function gunny_navEditAction(g_id, g_function) {
	_gunnyElementNavId(g_id).onclick = function(){g_function();};
}

function gunny_navDeleteAction(g_id, g_function) {
	_gunnyElementNavId(g_id).removeEventListener("click", g_function);
}

function gunny_navReset() {
	document.getElementById('gunny_navigator_list').innerHTML = '';
}

function gunny_getURL_Vars() {
    var vars = {};
    var parts = window.location.href.replace(/[?&]+([^=&]+)=([^&]*)/gi, function(m,key,value) {
        vars[key] = value;
    });
    return vars;
}

function gunny_getParam(g_parameter, g_defaultvalue) {
    var UrlParameter = g_defaultvalue;
    if (window.location.href.indexOf(g_parameter) > -1) {
        UrlParameter = gunny_getURL_Vars()[g_parameter];
    }
    return UrlParameter;
}

function gunny_loadJS(g_file, g_callback) {
    jQuery.ajax({
        url: g_file,
        dataType: 'script',
        success: g_callback,
        async: true
    });
}

function gunny_loadJSON(g_file, g_callback) {
	var rawFile = new XMLHttpRequest();
	rawFile.overrideMimeType("application/json");
	rawFile.open("GET", g_file, true);
	rawFile.onreadystatechange = function() {
		if (rawFile.readyState === 4 && rawFile.status == "200") {
			g_callback(rawFile.responseText);
		}
	}
	rawFile.send(null);
}

function gunny_loadHTML(g_file, g_targetId) {
	$('#'+g_targetId).load(g_file);
}

function gunny_getLoadPercent() {
	return Number(document.getElementById('gunny_loading_progress_bar').style.width.replace('%',''));
}

function gunny_setLoadPercent(g_var) {
	if (g_var >= 100) {
		g_var = 100;
		document.getElementById('gunny_loading').className = "gunny fade";
	}
	else {
		document.getElementById('gunny_loading').className = "gunny";
	}
	if (g_var < 0) { g_var = 0; }
	document.getElementById('gunny_loading_progress_bar').style.width = g_var + '%';
}

window.onload = function() {
	gunny_setLoadPercent(50);
	document.title = 'Powered by The GUNNY Engine';
	
	var g_manifest = {};
	g_manifest.webmanifest = {};
	g_manifest.gunny = {};
	
	gunny_loadJSON('manifest.json', function(text){
		g_json = JSON.parse(text);
		document.title = g_json.name;
		document.getElementById('gunny_navigator_name').innerHTML = g_json.short_name;
		_gunnyElementHead().innerHTML = str_ireplace('[GUNNY_App_Name]', g_json.name, _gunnyElementHead().innerHTML);
		_gunnyElementHead().innerHTML = str_ireplace('[GUNNY_App_ShortName]', g_json.short_name, _gunnyElementHead().innerHTML);
		_gunnyElementHead().innerHTML = str_ireplace('[GUNNY_App_URL]', location.href, _gunnyElementHead().innerHTML);
		_gunnyElementHead().innerHTML = str_ireplace('[GUNNY_App_Description]', g_json.description, _gunnyElementHead().innerHTML);
		_gunnyElementHead().innerHTML = str_ireplace('[GUNNY_App_ThemeColor]', g_json.theme_color, _gunnyElementHead().innerHTML);
		gunny_setLoadPercent(gunny_getLoadPercent() + 15);
		g_manifest.webmanifest = g_json;
	});
	
	gunny_loadJSON('manifest.gunny.json', function(text){
		g_json = JSON.parse(text);
		_gunnyElementHead().innerHTML = str_ireplace('[GUNNY_App_Version]', g_json.version, _gunnyElementHead().innerHTML);
		_gunnyElementHead().innerHTML = str_ireplace('[GUNNY_App_Keyword]', g_json.keyword, _gunnyElementHead().innerHTML);
		gunny_setLoadPercent(gunny_getLoadPercent() + 10);
		g_manifest.gunny = g_json;
	});
	
	if (typeof gunny_u_onload == 'function') { 
		gunny_u_onload(g_manifest);
	}
}