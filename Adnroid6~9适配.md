### 1、Android6.0
* 危险权限动态申请
###  2、Android7.0
#### 2.1 应用间文件共享
#### 2.2 APK签名 
* 只勾选v1:传统签名方式,7.0+版本不会使用v2安全验证方式
* 只勾选v2: 7.0-版本会显示未安装，7.0+版本使用v2安全验证方式
建议同时勾选v1,v2
#### 2.3 SharedPreferences异常
在Android7.0+版本中，给SharedPreferences设置Context.MODE_WORLD_READABLE或Context.MODE_WORLD_WRITEABLE，会触发SecurityException。
把MODE_WORLD_READABLE 模式换成 MODE_PRIVATE就好了。
### 3、Android8.0
#### 3.1 PHONE权限组新增加权限
* ANSWER_PHONE_CALLS：允许您的应用通过编程方式接听呼入电话。要在您的应用中处理呼入电话，您可以使用 acceptRingingCall() 函数。
* READ_PHONE_NUMBERS ：权限允许您的应用读取设备中存储的电话号码。
#### 3.2 通知
#### 3.3 安装APK
在配置文件中添加允许安装未知来源应用权限
```
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
```
这里注意，加上这个权限之后，在运行的时候，还是要去检查权限的。和Android6.0动态申请权限不一样，这里检查有没有权限要通过context.getPackageManager().canRequestPackageInstalls()方法来检查，返回true就是有权限了，没有要自己写一个提示框去提示用户。然后通过Intent去跳转到设置页面。
```
//注意这个是8.0新API,直接跳转到允许安装位置来源的页面
Uri uri = Uri.fromParts("package", mActivity.getPackageName(), null);
intent = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, uri);
```

### 4、Android9.0
#### 4.1网络
在Android9.0+版本中，默认仅支持https请求，也就是说，你的App中如果使用http请求将会被限制。
首先创建network_security_config.xml文件
```
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="true" />
</network-security-config>
```
然后在配置文件的application标签中添加
```
  android:networkSecurityConfig="@xml/network_security_config"
```

#### 4.2 wifi模块
在android8.0/8.1中扫描wifi列表、获取wifi名称等功能 需要的权限一下之一
* ACCESS_FINE_LOCATION
* ACCESS_COARSE_LOCATION
* CHANGE_WIFI_STATE
在Android9.0+本版中的相关功能需要满足以下全部条件
* ACCESS_FINE_LOCATION 或 ACCESS_COARSE_LOCATION 权限。
*  CHANGE_WIFI_STATE 权限。

#### 4.3 Intent
使用非Activity的Context跳页页面报错
```
 android.util.AndroidRuntimeException: Calling startActivity() from outside of an Activity  context requires the FLAG_ACTIVITY_NEW_TASK flag. Is this really what you want?
```
这时候需要在Intent上加一个flag.
```
Intent intent = new Intent(MainActivity.this, MainActivity2.class);
intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
AppConfigInIt.getApplicationContext().startActivity(intent);
```

