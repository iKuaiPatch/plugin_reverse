AjaxPost = function (url, data, success, error, async) {
    var para = {
        url: url,
        data: data || {},
        success: success || function () {},
        error: error || function () {}
    };
    async = async == undefined ? true : async;
    var xhr = new XMLHttpRequest();
    xhr.open('POST', para.url, async);
    xhr.onload = function (e) {
        if (xhr.status == 200 || xhr.status == 304 || xhr.status == 0) {
            para.success(JSON.parse(e.target.responseText));
        } else {
            para.error(JSON.parse(e.target));
        }
    };
    xhr.onerror = function (e) { error(e); };
    if (!async) {
        try {
            xhr.timeout = 1000;
            xhr.ontimeout = function () { error('timeout'); };
        } catch (e) {
            setTimeout(function () {
                xhr.abort();
                error('timeout');
            }, 1000);
        }
    }
    xhr.setRequestHeader('Content-Type', 'application/json');
    xhr.send(JSON.stringify(para.data));
};
AjaxGet = function (url,success,error){
        var xhr = new XMLHttpRequest();
        xhr.open('get', url) 
        xhr.send();
        xhr.onload = function (e) {
            if (xhr.status == 200 || xhr.status == 304 || xhr.status == 0) {
                success(JSON.parse(e.target.responseText));
            } else {
                error(JSON.parse(e.target));
            }
        }
};
AjaxuploadFile = function (url,data,success, error, async) {
    var that = this;
    var para = {
        url: url,
        data: data || {},
        success: success || function () {},
        error: error || function () {}
    };
    async = async == undefined ? true : async;
    var xhr=new XMLHttpRequest();
    xhr.open('post',para.url,async);
    xhr.onload = function (e) {
        if (xhr.status == 200 || xhr.status == 304 || xhr.status == 0) {
            para.success(JSON.parse(e.target.responseText));
        } else {
            para.error(JSON.parse(e.target));
        }
    };
    xhr.onerror = function (e) { error(e); };
    xhr.onreadystatechange=function (){
        //readystate为4表示请求已完成并就绪
        // if(this.readyState==4){
        //     document.getElementById('precent').innerHTML=this.responseText;
        //     //在进度条下方插入百分比
        // }
    }
    xhr.upload.onprogress=function (ev){
        if(ev.lengthComputable){
            var precent =100 * ev.loaded/ev.total;
            that.uploadConf.Percentage = Math.round(precent) + '%';
        }
    }
    xhr.send(data);
};
MessageTip = function(message,color){
    this.messageNotice = true;
    this.Message = message;
    this.msgcolor = color;
    setTimeout(()=>{
        this.messageNotice = false;
    },1500)
}