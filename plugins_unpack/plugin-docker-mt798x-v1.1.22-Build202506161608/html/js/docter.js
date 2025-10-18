
filterSpecialChar3Validator = (value) => {
    var reg = /[\[\]\{\}\,\%\=\?\^\(\)\`\!\#\！\“\’\‘\”\、\~\'\"\;\\\/\&\*\<\>\$\|]+/;
    return !reg.test(value);
};
strLenBetweenValidator = (value, args) => {
    let len = value.length;
    if (len < args[0] || len > args[1]) {
        return false;
    } else {
        return true;
    }
};
betweenValidator = (value,arr) => {
    if(value >= arr[0] && value <= arr[1]){
        return false;
    }else {
        return true;
    }
};
DockerStartcmdValidator = (value) => {
    var reg =/^[A-Za-z0-9_\-.,\/]+$/;
    if (reg.test(value)) {
        return true;
    } else {
        return false;
    }
};
formatBytes = function (v, t, n) {
    if (isNaN(v)) return t ? '0 B/s' : '0 B';
    v = parseInt(v);
    if (v == 0) return t ? '0 B/s' : '0 B';

    var ua = [' B', ' KB', ' MB', ' GB', ' TB', ' PB', ' EB', ' ZB', ' YB', ' DB', ' NB'];
    if (t) {
        // 如果参数t为true，则调用另外一套单位
    	ua = [' B/s', ' KB/s', ' MB/s', ' GB/s', ' TB/s', ' PB/s', ' EB/s', ' ZB/s', ' YB/s', ' DB/s', ' NB/s'];
    }

    for (var i = 0; v >= 1024 && i < 10; i++) {
        v /= 1024;
    }

    var res = (v >= 999 ? (v / 1024).toFixed(2) : v.toFixed(2)) * 1;
    if (n) {
        // 如果参数n为true，则保留包括小数点前后的3个数字
        if (res > 10 && res < 100) {
            res = res.toFixed(1);
        }
        if (res >= 100 && res < 999) {
            res = res.toFixed(0);
        }
    }

    return v >= 999 ? res + ua[i + 1] : res + ua[i];
};
RequiredValidator = (value) =>{
    if(value == ''){
        return true;
    }
    return false;
}
IPMaskValidator = (value,args) => {
    var flag = true;
    if (value) {
        if (isIpMask(value)) {
            flag = true;
        }else{
            flag = false;
        }
    } else {
        flag = false;
    }

    return flag;
};
IPorIPMaskValidator = (value,args) => {
    var flag = true;
    if(value == '' || value == undefined) {
        flag = true;
    }
    if (value) {
        if (isIp(value)) {
            flag = true;
        }else{
            flag = false;
        }
    }

    return flag;
};
IPConflictValdator = (ipaddr, gateway) => {
    if(gateway == '' || ipaddr == '' || ipaddr == undefined || gateway == undefined) {
        return false;
    }
    if(ipaddr == gateway) {
        return true;
    }
    return false;
};
IPrangeValidator = (ipaddr, ip_str) => {
    var mark_len = 32;
    if(ip_str == '' || ipaddr == '' || ipaddr == undefined || ip_str == undefined) {
        return false;
    }
    if (ip_str.search("/")!=-1) {
        var strs= new Array(); 
        strs=ip_str.split("/"); 
    }
    mark_len = strs[1];
    var ip = _ip2int(strs[0]);
    var netmasknum = 0xFFFFFFFF << (32 - mark_len) & 0xFFFFFFFF;
    var netmask = _int2iP(netmasknum);
    var ip_start = ip & netmasknum;
    var ip_end = ip | (~netmasknum) & 0xFFFFFFFF;
    // let ip_arr = ipaddr.split(".");
    // let mask_arr = netmask.split(".");
    // var res1 = ipRange(ip_arr,mask_arr)
    // var res2 = ipRange(_int2iP(ip_start).split("."),mask_arr)
    // var res3 = ipRange(_int2iP(ip_end).split("."),mask_arr)
    var ipvalue = _ip2int(ipaddr);
    var startipnum = _ip2int(_int2iP(ip_start));
    var endipnum = _ip2int(_int2iP(ip_end*1-1));
    if(ipvalue > endipnum || ipvalue <= startipnum){
        return true;
    }else {
        return false; 
    }
    // if((res1 != res2 || res1 != res3)) {
    //     return true;
    // }else {
    //     return false;
    // }
    return true;
};
ipRange = function (ip,netmask) {
    let net1, net2, net3, net4;
    net1 = parseInt(ip[0]) & parseInt(netmask[0]);
    net2 = parseInt(ip[1]) & parseInt(netmask[1]);
    net3 = parseInt(ip[2]) & parseInt(netmask[2]);
    net4 = parseInt(ip[3]) & parseInt(netmask[3]);
    return  net1 + '.' + net2 + '.' + net3 + '.' + net4;
}
//整型解析为IP地址
_int2iP = function (num) 
{
  var str;
  var tt = new Array();
  tt[0] = (num >>> 24) >>> 0;
  tt[1] = ((num << 8) >>> 24) >>> 0;
  tt[2] = (num << 16) >>> 24;
  tt[3] = (num << 24) >>> 24;
  str = String(tt[0]) + "." + String(tt[1]) + "." + String(tt[2]) + "." + String(tt[3]);
  return str;
}
//IP转成整型
_ip2int = function (ip) 
{
  var num = 0;
  ip = ip.split(".");
  num = Number(ip[0]) * 256 * 256 * 256 + Number(ip[1]) * 256 * 256 + Number(ip[2]) * 256 + Number(ip[3]);
  num = num >>> 0;
  return num;
}
isObject = function (obj) {
    try {
        return typeof obj === 'object' && obj.constructor == Object;
    } catch (e) {
        return false;
    }
};
isArray = function (obj) {
    try {
        Array.prototype.toString.call(obj);
        if (obj.push && obj.unshift && obj.pop && obj.shift && obj.join && obj.concat && obj.splice && obj.slice && obj.sort && obj.reverse) {
            return true;
        }
    }
    catch (e) { }
    return false;
};
isString = function (str) {
    return typeof str == 'string' && str.constructor == String;
};
 //是否是数字
isNum = function (value) {
    return /^[0-9]+$/.test(value);
};
// 是否是ip
isIp = function (ip) {
    var flag = true;
    let reg = /^(\d{1,2}|1\d\d|2[0-4]\d|25[0-5])\.(\d{1,2}|1\d\d|2[0-4]\d|25[0-5])\.(\d{1,2}|1\d\d|2[0-4]\d|25[0-5])\.(\d{1,2}|1\d\d|2[0-4]\d|25[0-5])$/;
    if (reg.test(ip)) {
        let _arr = ip.split('.');
        if (!checkIpIsNum(_arr) || !checkIpPass(_arr)) {
            flag = false;
        }
    } else {
        flag = false;
    }
    return flag;
};
// 是否是带掩码的ip
isIpMask = function (ip) {
    // 判断斜杠后的数字范围是否在1-32之间
    let slashPos = ip.indexOf('/');
    if (slashPos !== -1) {
        var num = ip.split('/')[1];
        ip = ip.split('/')[0];
        if (!isIp(ip)) {
            return false;
        }
        //检测后边是数字还是ip
        if (isNum(num)) {
            if (num > 32 || num < 0) {
                return false;
            }
        } else {
            if (!isIp(num)) {
                return false;
            }
        }
    } else {
        return false;
    }

    return isIp(ip);
};
checkIpIsNum = function (ip_arr) {
    var flag = true;
    if (ip_arr.length > 0) {
        for (var i = 0; i < ip_arr.length; i++) {
            var data = ip_arr[i]
            if (!/^\d+$/.test(data) || data > 255 || data == '')
                flag = false;
            if (data.length > 1) {
                if (data[0] == '0')
                    flag = false;
            }
        }
    } else {
        flag = false;
    }
    return flag;
};
checkIpPass = function (ip_arr) {
    var flag = true;
    var cnt = ip_arr.length;

    if (cnt < 4) {
        flag = false;
    } else {
        if (ip_arr[0] == 239) {
            flag = true;
        }
        if (cnt > 4) {
            flag = false;
        } else if (cnt >= 2) {
            if (ip_arr[0] == 169 && ip_arr[1] == 254)
                flag = false;

            for (var i = 0; i < cnt; i++) {
                if (ip_arr[i] < 0 || ip_arr[i] > 255) {
                    flag = false;
                }
            }
        }
    }
    return flag;
};
IPV6Validators = (value, mask) => {
    //mask为1的时候，必须有掩码，否则不能有掩码
    if(value == undefined || value == '') {
        return true;
    }
    mask = mask * 1 == 1;
    let reg = /^([a-f0-9]{1,4}(:[a-f0-9]{1,4}){7}|[a-f0-9]{1,4}(:[a-f0-9]{1,4}){0,7}::[a-f0-9]{0,4}(:[a-f0-9]{1,4}){0,7})$/;
    let reg2 = /^([A-F0-9]{1,4}(:[A-F0-9]{1,4}){7}|[A-F0-9]{1,4}(:[A-F0-9]{1,4}){0,7}::[A-F0-9]{0,4}(:[A-F0-9]{1,4}){0,7})$/;
    if (value != '') {
        let arr = value.split('/'), len = arr.length > 1;
        if (!reg.test(arr[0]) && !reg2.test(arr[0])) {
            return false;
        }
        if (mask && len) {
            return arr[1] * 1 > 0 && arr[1] * 1 < 129; 
        } else if (mask && !len || !mask && len) {
            return false;
        } else {
            return true;
        }
    }
    return false;
};
const IPV6GatewayValidator = (value, mask) => {
    if(value == '' || value == undefined) {
        return true; 
    }
    //mask为1的时候，必须有掩码，否则不能有掩码
    let reg = /^([a-f0-9]{1,4}(:[a-f0-9]{1,4}){7}|[a-f0-9]{1,4}(:[a-f0-9]{1,4}){0,7}::[a-f0-9]{0,4}(:[a-f0-9]{1,4}){0,7})$/;
    let reg2 = /^([A-F0-9]{1,4}(:[A-F0-9]{1,4}){7}|[A-F0-9]{1,4}(:[A-F0-9]{1,4}){0,7}::[A-F0-9]{0,4}(:[A-F0-9]{1,4}){0,7})$/;
    if (value != '') {
        if (!reg.test(value) && !reg2.test(value)) {
            return false;
        }else {
            return true; 
        }
    }
    return false;
}; 
copyStr = function(data) {
    var result = {};
    result =  data.replace(/\%/g, '%25').replace(/\s/g, ' ').replace(/ /g, '%20')
    .replace(/\"/g, '%22').replace(/\`/g, '%60').replace(/\$/g, '%24').replace(/\&/g, '%26')
    .replace(/\;/g, '%3B').replace(/\\/g, '%5C').replace(/\|/g, '%7C').replace(/\'/g, '%27')
    .replace(/\//g, '%2F').replace(/\./g, '%2E').replace(/\?/g, '%3F').replace(/\=/g, '%3D');
    return result;
};
copyObj = function copy(code, obj) {
    if (code === undefined) code = '';
    if (obj === undefined) obj = {};
    var result = {};
    for (var key in obj) {
        if (key === 'copy') {
            continue;
        }

        if (isArray(obj[key])) {
            result[key] = copyAry(code, obj[key]);
        }
        else if (isString(obj[key])) {
            if (code === 'encode') {
                // 特殊处理，凡事备注，都做一次trim，去掉前后的空格
                if (key == 'comment') {
                    obj[key] = obj[key].trim();
                }

                if (key == 'mac' || key == 'macs') {
                    obj[key] = obj[key].replace(/-/g, ':');
                }

                result[key] = obj[key].replace(/\%/g, '%25').replace(/\s/g, ' ').replace(/ /g, '%20')
                    .replace(/\"/g, '%22').replace(/\`/g, '%60').replace(/\$/g, '%24').replace(/\&/g, '%26')
                    .replace(/\;/g, '%3B').replace(/\\/g, '%5C').replace(/\|/g, '%7C').replace(/\'/g, '%27');
            }
            else if (code === 'decode') {
                result[key] = obj[key].replace(/\%20/g, ' ').replace(/\%25/g, '%').replace(/\%22/g, '\"')
                    .replace(/\%60/g, '`').replace(/\%24/g, '$').replace(/\%26/g, '&').replace(/\%3B/g, ';')
                    .replace(/\%5C/g, '\\').replace(/\%7C/g, '|').replace(/\%27/g, "'");
            }
            else {
                result[key] = obj[key];
            }
        }
        else if (isObject(obj[key])) {
            result[key] = copy(code, obj[key]);
        }
        else {
            result[key] = obj[key];
        }
    }
    return result;
};
copyAry = function copy(code, ary) {
    if (code === undefined) code = '';
    if (ary === undefined) ary = [];
    var result = [];
    for (var i = 0; i < ary.length; i++) {
        if (isArray(ary[i])) {
            result[i] = copy(code, ary[i]);
        }
        else if (isString(ary[i])) {
            if (code === 'encode') {
                result[i] = ary[i].replace(/\%/g, '%25').replace(/\s/g, ' ').replace(/ /g, '%20')
                    .replace(/\"/g, '%22').replace(/\`/g, '%60').replace(/\$/g, '%24').replace(/\&/g, '%26')
                    .replace(/\;/g, '%3B').replace(/\\/g, '%5C').replace(/\|/g, '%7C').replace(/\'/g, '%27');
            }
            else if (code === 'decode') {
                result[i] = ary[i].replace(/\%20/g, ' ').replace(/\%25/g, '%').replace(/\%22/g, '\"')
                    .replace(/\%60/g, '`').replace(/\%24/g, '$').replace(/\%26/g, '&').replace(/\%3B/g, ';')
                    .replace(/\%5C/g, '\\').replace(/\%7C/g, '|').replace(/\%27/g, "'");
            }
            else {
                result[i] = ary[i];
            }
        }
        else if (isObject(ary[i])) {
            result[i] = copyObj(code, ary[i]);
        }
        else {
            result[i] = ary[i];
        }
    }
    return result;
};

function getLocalTime(nS) {  
    return new Date(parseInt(nS) * 1000).toLocaleString().replace(/:\d{1,2}$/,' ');  
}
function formatDate(datetime) {
            // 获取年月日时分秒值  slice(-2)过滤掉大于10日期前面的0
            var datetime = new Date(datetime*1000)
            var year = datetime.getFullYear(),
             month = ("0" + (datetime.getMonth() + 1)).slice(-2),
             date = ("0" + datetime.getDate()).slice(-2),
             hour = ("0" + datetime.getHours()).slice(-2),
             minute = ("0" + datetime.getMinutes()).slice(-2),
             second = ("0" + datetime.getSeconds()).slice(-2);
         // 拼接
            var result = year + "-"+ month +"-"+ date +" "+ hour +":"+ minute +":" + second;
            // 返回
            return result;
        }
    
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



Language = {
    "Image_management":["镜像管理","鏡像管理","Image management"],
    "Interface_management":["接口管理","接口管理","Interface management"],
    "delete":["删除","删除","Delete"],
    "Add":["添加","添加","Add to"],
    "name":["名称","名稱","Name"],
    "CPU_usage":["CPU使用率","CPU使用率","CPU usage"],
    "Memory_footprint":["内存占用","內存佔用","Memory footprint"],
    "Network_Interface":["网络接口","網絡接口","Network Interface"],
    "Running_time":["运行时长","運行時長","Running time"],
    "Self_start":["开机自启","開機自啟","Self-start"],
    "status":["状态","狀態","status"],
    "operating":["操作","操作","operating"],
    "Help_tip":["帮助提示","幫助提示","Help tips"],
    "Help_content":["CPU和内存使用率表示容器对宿主机资源的占用情况。","CPU和內存使用率表示容器對宿主機資源的佔用情況","The CPU and memory usage rate indicates the occupancy of host resources by the container."],
    "yes":["是","是","Yes"],
    "no":["否","否","No"],
    "activated":["已启用","已啟用","activated"],
    "terminated":["已停用","已停用","terminated"],
    "Created":["已创建","已創建","Created"],
    "Console":["控制台","控制台","Console"],
    "Enable":["启用","啟用","Enable"],
    "Deactivate":["停用","停用","Deactivate"],
    "submit":["提交","提交","submit"],
    "edit":["编辑","編輯","edit"],
    "Container_name":["容器名称","容器名稱","Container name"],
    "tip":["不支持特殊字符,除(: @ - _ + . )","不支持特殊字符,除(: @ - _ + . )","Special characters are not supported, except (: @-_ +.)"],
    "tip2":["字符长度必须在1-64之间","字符長度必須在1-64之間","The character length must be between 1-64"],
    "tip3":["容器对宿主机CPU最大占用率","容器對宿主機CPU最大佔用率","The maximum CPU usage of the container to the host"],
    "tip4":["必须在1-100之间.","必須在1-100之間.","Must be between 1-100."],
    "tip5":["容器对宿主机内存最大占用值","容器對宿主機內存最大佔用值","The maximum memory occupied by the container on the host"],
    "tip6":["必须在64-","必須在64-","Must be between 64-"],
    "tip7":["之间","之間",""],
    "tip8":["如需管理接口，请前往容器列表“接口管理”编辑","如需管理接口，請前往容器列表“接口管理”編輯","If you need to manage the interface, please go to the container list 'interface management' to edit"],
    "tip9":["不能包含特殊字符","不能包含特殊字符","Cannot contain special characters"],
    "tip10":["请前往“磁盘管理-磁盘分区”页面，新建“普通存储”分区，才能添加容器！","請前往“磁盤管理-磁盤分區”頁面，新建“普通存儲”分區，才能添加容器！","Please go to the 'Disk Management-Disk Partition' page and create a new 'General Storage' partition to add a container!"],
    "tip11":["提示：提交镜像后，请前往“镜像管理”页面查看","提示：提交鏡像後，請前往“鏡像管理”頁面查看","Tip: After submitting the image, please go to the 'Image Management' page to view"],
    "tip12":["最多支持存放20个镜像文件","最多支持存放20個鏡像文件","Supports storing up to 20 image files"],
    "tip13":["绑定云平台可以支持云端容器统一部署及管理，","綁定雲平台可以支持雲端容器統一部署及管理，","Binding cloud platform can support unified deployment and management of cloud containers,"],
    "tip14":["请输入镜像名称","請輸入鏡像名稱","Please enter the mirror name"],
    "tip15":["填写镜像文件绝对路径","填寫鏡像文件絕對路徑","Fill in the absolute path of the image file"],
    "tip16":["继续操作将会修改Docker镜像库存放路径，是否确认继续？","繼續操作將會修改Docker鏡像庫存放路徑，是否確認繼續？","Continuing the operation will modify the storage path of the Docker image inventory. Are you sure to continue?"],
    "tip17":["文件迁移中，请勿关闭页面！","文件遷移中，請勿關閉頁面！","Do not close the page during file migration!"],
    "tip18":["提示：导出镜像后，请前往“磁盘管理-文件管理”页面下载","提示：導出鏡像後，請前往“磁盤管理-文件管理”頁面下載","Tip: After exporting the image, please go to the 'Disk Management-File Management' page to download"],
    "tip19":["当前结果由Docker Hub提供","當前結果由Docker Hub提供","Current results provided by Docker Hub"],
    "tip20":["不支持当前版本","不支持當前版本","Does not support current version"],
    "tip21":["导出成功","導出成功","Export successfully"],
    "tip23":["Docker服务设置发生变化，继续操作会重启Docker服务，是否确定？","Docker服務設置發生變化，繼續操作會重啟Docker服務，是否確定？","If the Docker service settings change, continue to restart the Docker service. Are you sure?"],
    "tip24":["必填字段","必填字段","Required fields"],
    "tip25":["接口使用中，不支持操作！","接口使用中，不支持操作！","The interface is in use and does not support operation!"],
    "tip26":["下载完成！","下載完成！","Download completed!"],
    "tip27":["保存成功","保存成功","Saved successfully"],
    "tip28":["镜像使用中，无法删除！","鏡像使用中，無法刪除！","The mirror is in use and cannot be deleted!"],
    "tip29":["Docker实例数量已达上限!","Docker實例數量已達上限!","The number of Docker instances has reached the upper limit"],
    "tip30":["镜像数量已达上限!","鏡像數量已達上限!","The number of mirrors has reached the upper limit!"],
    "tip31":["切换存储分区后，原分区中的容器会自动停用，用户可以前往“磁盘管理-文件管理”目录下手动迁移。","切換存儲分區後，原分區中的容器會自動停用，用戶可以前往“磁盤管理-文件管理”目錄下手動遷移。","After the storage partition is switched, the container in the original partition will be automatically disabled, and the user can go to the 'Disk Management-File Management' directory to manually migrate"],
    "tip32":["请填写有效路径","請填寫有效路徑","Please fill in a valid path"],
    "tip33":["镜像文件加载中,请勿关闭页面!","鏡像文件加載中,請勿關閉頁面!","The image file is loading, please do not close the page!"],
    "tip34":["请输入正确ip地址","請輸入正確ip地址","Please enter the correct ip address"],
    "tip35":["ip地址不在网络接口网段范围内","ip地址不在網絡接口網段範圍內","IP address is not within the network interface network segment range"],
    "tip36":["IP地址与网络接口网关冲突","IP地址與網絡接口網關衝突","IP address conflicts with network interface gateway"],
    "tip37":["字符长度必须在0-64之间","字符長度必須在0-64之間","The character length must be between 0-64"],
    "tip38":["ipv6网段格式不正确","ipv6網段格式不正確","ipv6 network segment format is incorrect"],
    "tip39":["字符长度必须在1-11之间","字符長度必須在1-11之間","The character length must be between 1-11"],
    "tip40":["ipv4网段格式不正确","ipv4網段格式不正確","ipv4 network segment format is incorrect"],
    "tip41":["ipv4网关格式不正确","ipv4網關格式不正確","ipv4 gateway format is incorrect"],
    "tip42":["ipv6网关格式不正确","ipv6網關格式不正確","ipv6 gateway format is incorrect"],
    "tip43":["内存不能小于64M","內存不能小於64M","The memory cannot be less than 64M"],
    "tip44":["ipv6地址格式不正确","ipv6地址格式不正確","ipv6 address format is incorrect"],
    "tip45":['可用内存不足64M，请增加内存',"可用內存不足64M，請增加內存","The available memory is less than 64M, please increase the memory"],
    "tip46":["容器名称已存在","容器名稱已存在","Container name already exists"],
    "tip47":["网络接口变更，请更新配置","網路介面變更，請更新配寘","The network interface has changed, please update the configuration"],
    "tip48":["请输入镜像标签","請輸入鏡像標籤","Please enter the image label"],
    "tip49":["默认为最新版本，可以自定义填写TAG名称","默認為最新版本，可以自定義填寫TAG名稱","By default, the TAG name is the latest version. You can customize the tag name"],
    "CPU_usage":["CPU占用率(%)","CPU佔用率(%)","CPU usage (%)"],
    "Memory_footprint":["内存占用(M)","內存佔用(M)","Memory footprint (M)"],
    "Select_imagefile":["选择镜像文件","選擇鏡像文件","Select image file"],
    "Network_mode":["网络模式","網絡模式","Network mode"],
    "bridging":["桥接","橋接","bridging"],
    "Host":["主机","主機","Host"],
    "customize":["自定义","自定義","customize"],
    "Select_networkinterface":["选择网络接口","選擇網絡接口","Select network interface"],
    "Self_start":["开机自启","開機自啟","Self-start"],
    "advanced_settings":["高级设置","高級設置","advanced settings"],
    "Mount_directory":["挂载目录","掛載目錄","Mount directory"],
    "File_management":["文件管理","文件管理","File management"],
    "Source_path":["源路径","源路徑","Source path"],
    "Target_path":["目标路径","目標路徑","Target path"],
    "Environment_variable":["环境变量","環境變量","Environment variable"],
    "variable_name":["变量名","變量名","Variable name"],
    "Value":["值","值","Value"],
    "Start_command":["启动命令","啟動命令","Start command"],
    "save":["保存","保存","save"],
    "cancel":["取消","取消","cancel"],
    "confirm":["确认","確認","confirm"],
    "Set_path":["设置存储路径","設置存儲路徑","Set storage path"],
    "Goto_settings":["前往设置","前往設置","Go to settings"],
    "Submit_mirror":["提交镜像","提交鏡像","Submit mirror"],
    "submit_method":["镜像提交方式","鏡像提交方式","Mirror submission method"],
    "Save_as":["另存为","另存為","Save as"],
    "cover":["覆盖","覆蓋","cover"],
    "Image_name":["镜像名称","鏡像名稱","Image name"],
    "deletetip":["请选择要操作的数据！","請選擇要操作的數據！","Please select the data to be operated!"],
    "deletetip1":["删除后将无法恢复，是否确定删除？","刪除後將無法恢復，是否確定刪除？","After deletion, it cannot be restored. Are you sure to delete?"],
    "Storage_path":["存储路径","存儲路徑","Storage path"],
    "Export":["导出","導出","Export"],
    "Change_time":["修改时间","修改時間","Change the time"],
    "Details":["详情","詳情","Details"],
    "Goto_binding":["前往绑定","前往綁定","Go to binding"],
    "Path_set":["路径设置","路徑設置","Path setting"],
    "Select_partition":["选择目标分区","選擇目標分區","Select target partition"],
    "Add_mirror":["添加镜像","添加鏡像","Add mirror"],
    "Upload_method":["上传方式","上傳方式","Upload method"],
    "Reference_mirror":["引用镜像","引用鏡像","Reference mirror"],
    "Mirror_path":["镜像路径","鏡像路徑","Mirror path"],
    "search":["搜索","搜索","search for"],
    "prompt":["提示","提示","prompt"],
    "Export_image":["导出镜像","導出鏡像","Export image"],
    "Export_imagename":["导出镜像名称","導出鏡像名稱","Export image name"],
    "Select_storagepartition":["选择存储分区","選擇存儲分區","Select storage partition"],
    "success":["操作成功","操作成功","Successful operation"],
    "error":['操作失败',"操作失敗","operation failed"],
    "mirror_error":["添加镜像失败！","添加鏡像失敗","Failed to add mirror!"],
    "Interface_name":["接口名称","接口名稱","Interface name"],
    "network_segment":["网段","網段","network segment"],
    "Gateway":["网关","網關","Gateway"],
    "Add_interface":["添加接口","添加接口","Add interface"],
    "Docker_service":["Docker服务","Docker服務","Docker service"],
    "Docker_list":["容器列表","容器列表","Container list"],
    "open":["开","開","open"],
    "close":["关","關","turn off"],
    "image_download":["镜像库下载","鏡像庫下載","Mirror library download"],
    "custom_download":["自定义下载","自定義下載","Custom download"],
    "description":["描述","描述","description"],
    "Attributes":["属性","屬性","Attributes"],
    "Star_rating":["星级","星級","Star rating"],
    "Check_code":["校验码","校驗碼","Check code"],
    "System":["系统/ARCH","系統/ARCH","System/ARCH"],
    "File_size":["文件大小","文件大小","File size"],
    "Mirro_settings":["镜像库设置","鏡像庫設置","Mirror library settings"],
    "download":["下载","下載","download"],
    "search_results":["搜索结果","搜索結果","search results"],
    "Image_libraryname":["镜像库名称","鏡像庫名稱","Image library name"],
    "address":["地址","地址","address"],
    "Enter_downloadpage":["进入下载页","進入下載頁","Enter the download page"],
    "return":["返回","返回","return"],
    "official":["官方","官方","official"],
    "unofficial":["非官方","非官方","unofficial"],
    "Downloadpage":["下载页","下載頁","Download page"],
    "Service_normal":["服务正常","服務正常","Service is normal"],
    "Service_notstarted":["服务异常","服務異常","Service exception"],
    "partition_management":["存储分区管理","存儲分區管理","Storage partition management"],
    "Storagepartition_settings":["存储分区设置","存儲分區設置","Storage partition settings"],
    "Library_name":["库名称","庫名稱","Library name"],
    "Mirror_address":["镜像地址","鏡像地址","Mirror address"],
    "Service_settings":["服务设置","服務設置","Service settings"],
    "MirrorURL":["镜像库URL","鏡像庫URL","Mirror URL"],
    "MirrorP":["默认镜像库 由毫秒镜像提供技术支持","默認鏡像庫 由毫秒鏡像提供技術支持","The default image library is supported by Mliev 1ms Mirror"],
    "Loading":["加载中","加載中","Loading"],
    "searching":["搜索中","搜索中","searching"],
    "Total":["共","共","Total"],
    "Article":["条","條","Article"],
    "Current_display":["当前显示","當前顯示","Current display"],
    "Jump":["跳转","跳轉","Jump"],
    "page":["页","頁","page"],
    "Per_page":["每页","每頁","Per page"],
    "seach_image":["镜像搜索","鏡像搜索","Mirror search"],
    "required":["不能为空","不能為空","Can not be empty"],
    "Download_progress":["下载进度","下載進度","Download progress"],
    "Image_size":["镜像大小","鏡像大小",'Mirror size'],
    "search_error":["搜索失败","搜索失敗","Search failed"],
    "Requesting_data":["正在请求数据……","正在請求數據……","Requesting data..."],
    "Mirror":["镜像","鏡像",'Mirror'],
    "IPadress":['IP地址',"IP地址","IP address"],
    "Optional":["选填","選填","Optional"],
    "Log":["日志","日誌","Log"],
    "IPv4":["IPv4地址","IPv4地址","IPv4 address"],
    "IPv6":["IPv6地址","IPv6地址","IPv6 address"],
    "time":["时间","時間","time"],
    "event":["事件","事件","event"],
    "IPv6_Gateway":["IPv6网关","IPv6網關","IPv6 Gateway"],
    "IPv4_Gateway":["IPv4网关","IPv4網關","IPv4 Gateway"],
    "Turn_on":["开启","開啟","Turn on"],
    "format":["格式","格式","format"],
    "log_detail":["日志详情","日誌詳情","Log details"],
    "Update":["更新","更新","Update"],
    "TAG_name":["TAG名称","TAG名稱","TAG name"]
}