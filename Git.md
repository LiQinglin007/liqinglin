## git
[参考链接](https://www.jianshu.com/p/6c5c359bde02)
### git工作区、暂存区、版本库
* 工作区是指，除了.git文件夹之外的，所有文件都属于工作区
* 暂存区是看不到的，是指在文件(文件夹)add到git仓库之后，commit之前，都属于暂存区
* 版本库是指在文件(文件夹)commit之后，填写了提交日志之后，存在版本库
### 版本回退
#### git revert 回退到指定版本<br>
这时候不会覆盖之前的，会从新起一个<br>
比如之前提交日志是A-B-C-D，现在在D，要回退到B，回退之后提交日志是A-B-C-D-B<br>
#### git reset 回退到指定版本<br>
这时候会覆盖之前的<br>
比如之前提交日志是A-B-C-D，现在在D，要回退到B，回退之后提交日志是A-B<br>
git reset的三种模式
* Hard<br>
 本地代码会直接回到指定的版本(B)代码，未提交的和已经提交过的，都会被替换成B版本的代码，<br>
 在C版本、D版本中新添加的文件也同样会被删除。<br>
 这个是指要清空暂存区和工作区，工作区的代码和文件将完全被指定的版本替换和覆盖。
* Soft<br>
本地代码会直接回到指定的版本(B)代码，在C、D版本中已经提交的内容恢复到暂存区，就是add到版本库中的。<br>
回退到指定版本。不清空暂存区，将已经提交的内容恢复到暂存区，不影响原来本地的文件(未提交的也不受影响).
* Mixed
本地代码会直接回到指定的版本(B)代码，在C、D版本中已经提交的内容恢复到未暂存状态，就是还没有add到版本库中的状态，后来在C、D版本中添加的问题将边成未添加到版本库中的状态。<br>
回退到指定版本。会将暂存区的内容和本地已经提交的内容全部恢复到未暂存的状态，不影响原来本地文件(未提交的也不受影响)。
### Git flow(分支)
Git Flow是广泛采用的一种工作流程。它有两个特点。
* 项目存在两个长期分支
* 项目存在三个短期分支
#### 长期分支
* 主分支-master<br>
主分支用于存放对外发布的版本，这是分支任何时候拿到，都是稳定的版本。
* 开发分支-dev<br>
开发分支用于日常开发，存放最新的开发版本。
#### 短期分支
* 功能分支-feature
* 补丁分支-hotfix
* 预发分支-release<br>

这三个短期分支用于开发新的功能，一旦开发完成，将会被合并到dev分支或者master分支，然后被删除。

### Git pull Requests
步骤入下：<br>
* 首先把别人的项目fork到自己的仓库下
* 然后拉到本地，并修改
* 推送到git
* 然后在自己的仓库中查看刚才已经修改并推送上来的项目
* 点击pull Requests
* 点击New pull request,再点击 Create pull request 按钮
* 填写修改内容，然后发送给项目作者，就算完成了。



