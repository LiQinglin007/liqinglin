

## 工作流程

* 1、初始化OkHttpClient
* 2、构建Request对象 并设置参数，请求地址，请求头，请求方式等参数
* 3、创建Call对象：OkHttpClient的newCall方法
* 4、获取Response响应：调用Call的execute()方法/enqueue()方法来

不管是Post请求还是Get请求，使用的流程都是一样的。但是内部逻辑确实不同的。我们一步一步来看

#### 1、初始化OkHttpClient

OkHttpClient的Builder()方法中提供了一些基本参数，我们可以对参数进行配置，比如拦截器，失败重连，超时时间等等。其中Dispatcher(调度分发器)和ConnectionPool(连接池）是核心点。

* Dispatcher:OkHttp请求的调度分发器，由它决定异步请求在线程池中是直接处理还是缓存等待。如果是同步请求，只能将相应的同步请求放到请求队列中执行。
* ConnectionPool:统一管理客户端和服务器之间连接的每一个Connection.作用在于，当Connection请求的URL相同时，是否可以选择复用；控制Connection保持保持打开状态还是服用。

#### 2、构建Request对象
```java
public static class Builder {
    @Nullable HttpUrl url;
    String method;
    Headers.Builder headers;
    @Nullable RequestBody body;

    /** A mutable map of tags, or an immutable empty map if we don't have any. */
    Map<Class<?>, Object> tags = Collections.emptyMap();

    public Builder() {
      this.method = "GET";
      this.headers = new Headers.Builder();
    }
}
```
在Builder()方法中可以看到，Request.Builder模式下默认的请求方式为GET请求，并且创建了Headers的内部类来保存头部信息。

```java
  Request(Builder builder) {
    this.url = builder.url;
    this.method = builder.method;
    this.headers = builder.headers.build();
    this.body = builder.body;
    this.tags = Util.immutableMap(builder.tags);
  }
```
然后是构造方法，指定请求方式，请求地址，请求头请求体等。

### 3、构建Call对象
```java
  /**
   * Prepares the {@code request} to be executed at some point in the future.
   */
  @Override public Call newCall(Request request) {
    return RealCall.newRealCall(this, request, false /* for web socket */);
  }

```
Call类只是一个接口，具体的实现在RealCall类中。
```java
  private RealCall(OkHttpClient client, Request originalRequest, boolean forWebSocket) {
    this.client = client;
    this.originalRequest = originalRequest;
    this.forWebSocket = forWebSocket;
    this.retryAndFollowUpInterceptor = new RetryAndFollowUpInterceptor(client, forWebSocket);
    this.timeout = new AsyncTimeout() {
      @Override protected void timedOut() {
        cancel();
      }
    };
    this.timeout.timeout(client.callTimeoutMillis(), MILLISECONDS);
  }

  static RealCall newRealCall(OkHttpClient client, Request 
originalRequest, boolean forWebSocket) {
	//实际调用的newCall()方法来获取Call
    // Safely publish the Call instance to the EventListener.
    RealCall call = new RealCall(client, originalRequest, forWebSocket);
    call.eventListener = client.eventListenerFactory().create(call);
    return call;
  }

```
调用Call.newCall()方法时，实际调用的是RealCall.newRealCall()方法，同时调用了new RealCall()方法。这时Call持有了第1、2步构建的OkHttpClient对象和Request对象，并且给这次请求配置了超时时间和RetryAndFollowUpInterceptor重定向拦截器。

### 4、获取Response响应：调用Call的execute()方法/enqueue()方法来

#### 4.1、call.execute实现同步请求
```java
 @Override public Response execute() throws IOException {
    synchronized (this) {
     //通过executed标志位来保证每个Call只能被执行一次，不会重复执行。
      if (executed) throw new IllegalStateException("Already Executed");
      executed = true;
    }
    captureCallStackTrace();
    timeout.enter();
    //开启监听事件，接收到回调通过dispatcher将Call添加到同步队列中
    eventListener.callStart(this);
    try {
	  //OkHttpClient调度器把构建的Call请求加入到同步执行队列中
      client.dispatcher().executed(this);
	 //拿到返回数据并返回
      Response result = getResponseWithInterceptorChain();
      if (result == null) throw new IOException("Canceled");
      return result;
    } catch (IOException e) {
      e = timeoutExit(e);
      eventListener.callFailed(this, e);
      throw e;
    } finally {
      client.dispatcher().finished(this);
    }
  }
```
RealCall.execute()方法将call添加到OkHttpClient的同步执行队列中，并且通过getResponseWithInterceptorChain()方法拿到返回值，结束之后执行Dispatcher的dinished方法。


```java
  /** Running synchronous calls. Includes canceled calls that haven't finished yet. */
  //同步执行队列
  private final Deque<RealCall> runningSyncCalls = new ArrayDeque<>();

 /** Used by {@code Call#execute} to signal it is in-flight. */
  synchronized void executed(RealCall call) {
    runningSyncCalls.add(call);
  }
```
Dispatcher.executed()方法就把Call添加到同步执行队列中。<br>
每次调用executed()方法时，Dispatcher会帮我们把同步请求添加到同步请求队列中，Dispatcher的作用就是维持Call请求状态和维护线程池，并把Call请求到相应的请求队列中，由请求队列决定当前Call请求是等待还是直接执行。

在请求结束后，执行Dispatcher().finished()方法
```java
  void finished(RealCall call) {
    finished(runningSyncCalls, call);
  }


  private <T> void finished(Deque<T> calls, T call) {
    //闲置接口
    Runnable idleCallback;
    synchronized (this) {
      if (!calls.remove(call)) throw new AssertionError("Call wasn't in-flight!");
      idleCallback = this.idleCallback;
    }
	//判断当前调度程序有没有正在调度
    boolean isRunning = promoteAndExecute();

    if (!isRunning && idleCallback != null) {
      idleCallback.run();
    }
  }
```
同步请求完成后调用finished()方法将队列中的请求移除，promoteAndExecute()返回是不是正在执行调度，如果已经没有可以调度的Call了，并且idleCallBack不为空，就调用Run,开启闲置接口。


整个GET请求的过程如下：

* 首先生成Call
* 然后由Dispatcher将Call添加到执行队列
* 然后由线程池来执行Call
* 请求结束后，Dispatcher将Call在执行队列中移除

#### 4.2、call.enqueue实现异步请求
```java
  @Override public void enqueue(Callback responseCallback) {
    synchronized (this) {
      if (executed) throw new IllegalStateException("Already Executed");
      executed = true;
    }
    captureCallStackTrace();
    eventListener.callStart(this);
    client.dispatcher().enqueue(new AsyncCall(responseCallback));
  }
```
RealCall.enqueue()方法将call添加到OkHttpClient的异步就绪队列中
```java
  /** Ready async calls in the order they'll be run. */
  //异步就绪队列
  private final Deque<AsyncCall> readyAsyncCalls = new ArrayDeque<>();

  /** Running asynchronous calls. Includes canceled calls that haven't finished yet. */
  //异步执行队列
  private final Deque<AsyncCall> runningAsyncCalls = new ArrayDeque<>();
  
    void enqueue(AsyncCall call) {
    synchronized (this) {
      readyAsyncCalls.add(call);
    }
    promoteAndExecute();
  }
```
Dispatcher对异步Call的调度 
```java
  //最大请求上限
  private int maxRequests = 64;
 //最大主机地址
  private int maxRequestsPerHost = 5;
//这个方法即完成了Dispatcher对异步请求的调度，又获取了Dispatcher是否正在调度的状态
 private boolean promoteAndExecute() {
    assert (!Thread.holdsLock(this));

    List<AsyncCall> executableCalls = new ArrayList<>();
    boolean isRunning;
    synchronized (this) {
  		//异步队列的调度在这里完成，去遍历就绪队列  
      for (Iterator<AsyncCall> i = readyAsyncCalls.iterator(); i.hasNext(); ) {
        AsyncCall asyncCall = i.next();
		//首先，异步执行队列的数量已经超过上限了，就说明现在Dispatcher已经没有在调度了，同事就绪的Call也不能加到执行队列中
        if (runningAsyncCalls.size() >= maxRequests) break; // Max capacity.
        //继续，如果执行队列还没达到上限，并且请求主机数达到最大主机数，就跳过这个Call,继续下一个Call.
        if (runningCallsForHost(asyncCall) >= maxRequestsPerHost) continue; // Host max capacity.

        i.remove();
        executableCalls.add(asyncCall);
        //最后把这个就绪的Call添加到执行队列中，完成异步请求的调度
        runningAsyncCalls.add(asyncCall);
      }
      //如果同步执行队列和异步执行队列的数量和不为0,那么就说明现在Dispatcher已经没有在调度了
      isRunning = runningCallsCount() > 0;
    }

    for (int i = 0, size = executableCalls.size(); i < size; i++) {
      AsyncCall asyncCall = executableCalls.get(i);
      asyncCall.executeOn(executorService());
    }

    return isRunning;
  }
  
  
  //获取同步执行队列和异步执行队列的数量和
   public synchronized int runningCallsCount() {
    return runningAsyncCalls.size() + runningSyncCalls.size();
  }
```
在promoteAndExecute()方法中，Dispatcher完成了对异步请求的调度。在Get请求中通过getResponseWithInterceptorChain()方法来获取返回数据，那么在Post方法中怎么来获取返回数据呢？我们想看异步队列的类型
```java
  /** Running asynchronous calls. Includes canceled calls that haven't finished yet. */
  //异步执行队列
  private final Deque<AsyncCall> runningAsyncCalls = new ArrayDeque<>();
```
这个AsyncCall是个什么东西呢？
```java
 final class AsyncCall extends NamedRunnable {
    private final Callback responseCallback;

    AsyncCall(Callback responseCallback) {
      super("OkHttp %s", redactedUrl());
      this.responseCallback = responseCallback;
    }

    String host() {
      return originalRequest.url().host();
    }

    Request request() {
      return originalRequest;
    }

    RealCall get() {
      return RealCall.this;
    }

    /**
     * Attempt to enqueue this async call on {@code executorService}. This will attempt to clean up
     * if the executor has been shut down by reporting the call as failed.
     */
    void executeOn(ExecutorService executorService) {
      assert (!Thread.holdsLock(client.dispatcher()));
      boolean success = false;
      try {
        executorService.execute(this);
        success = true;
      } catch (RejectedExecutionException e) {
        InterruptedIOException ioException = new InterruptedIOException("executor rejected");
        ioException.initCause(e);
        eventListener.callFailed(RealCall.this, ioException);
        responseCallback.onFailure(RealCall.this, ioException);
      } finally {
        if (!success) {
          client.dispatcher().finished(this); // This call is no longer running!
        }
      }
    }

    @Override protected void execute() {
      boolean signalledCallback = false;
      timeout.enter();
      try {
        Response response = getResponseWithInterceptorChain();
        if (retryAndFollowUpInterceptor.isCanceled()) {
          signalledCallback = true;
          responseCallback.onFailure(RealCall.this, new IOException("Canceled"));
        } else {
          signalledCallback = true;
          responseCallback.onResponse(RealCall.this, response);
        }
      } catch (IOException e) {
        e = timeoutExit(e);
        if (signalledCallback) {
          // Do not signal the callback twice!
          Platform.get().log(INFO, "Callback failure for " + toLoggableString(), e);
        } else {
          eventListener.callFailed(RealCall.this, e);
          responseCallback.onFailure(RealCall.this, e);
        }
      } finally {
        client.dispatcher().finished(this);
      }
    }
  }
```

```java
public abstract class NamedRunnable implements Runnable {
  protected final String name;

  public NamedRunnable(String format, Object... args) {
    this.name = Util.format(format, args);
  }

  @Override public final void run() {
    String oldName = Thread.currentThread().getName();
    Thread.currentThread().setName(name);
    try {
      execute();
    } finally {
      Thread.currentThread().setName(oldName);
    }
  }

  protected abstract void execute();
}
```

AsyncCall是RealCall的内部类，继承了NamedRunnable抽象类，NamedRunnable又实现了Runnable接口，所以可以通过ExecutorService执行。在AsynaCall的execute()方法中，我们看到了和Get请求相同的getResponseWithInterceptorChain()方法来拿到返回的Response。之后也是和GET请求相同，调用Disatcher的finished方法来将请求从异步请求队列中移除。结束整个请求。

POST的请求过程
* 生成Call
* 通过Disatcher来将Call添加到异步就绪队列中
* 在根据异步请求队列的数量将就绪队列中Call添加到请求队列中
* 然后将Call通过请求线程池来发起请求
* 拿到返回数据后，从异步执行队列中移除本次请求

#### 5、拦截器
在上述请求过程中，GET请求和POST请求最后都是通过getResponseWithInterceptorChain()方法来获取Response对象的。那么getResponseWithInterceptorChain()方法到底做了些什么呢？
```java
  Response getResponseWithInterceptorChain() throws IOException {
    // Build a full stack of interceptors.
    List<Interceptor> interceptors = new ArrayList<>();
    //用户自定义拦截器
    interceptors.addAll(client.interceptors());
    //重定向拦截器，负责失败重试，处理错误等
    interceptors.add(retryAndFollowUpInterceptor);
    //添加请求头拦截器，负责补充开发者在创建请求时缺失的一些不要的请求头以及压缩处理
    interceptors.add(new BridgeInterceptor(client.cookieJar()));
    //缓存处理拦截器
    interceptors.add(new CacheInterceptor(client.internalCache()));
    //与服务器建立连接
    interceptors.add(new ConnectInterceptor(client));
    if (!forWebSocket) {
      //网络拦截器
      interceptors.addAll(client.networkInterceptors());
    }
    //向服务器发送请求，从服务器读取数据的拦截器
    interceptors.add(new CallServerInterceptor(forWebSocket));
	//将拦截器集合传递到RealInterceptorChain中
    Interceptor.Chain chain = new RealInterceptorChain(interceptors, null, null, null, 0,
        originalRequest, this, eventListener, client.connectTimeoutMillis(),
        client.readTimeoutMillis(), client.writeTimeoutMillis());
	//责任链执行
    return chain.proceed(originalRequest);
  }
```
在这里构建了一个拦截器集合，并将拦截器集合传递到RealInterceptorChain中，执行责任链，拿到返回的响应，并返回。<br>

![拦截器](https://github.com/LiQinglin007/liqinglin/blob/master/img/OkHttp3工作流程_拦截器.png)

拦截器有两种：App层面的拦截器和网络拦截器<br>这里Interceptor也是一个接口，实现类在RealInterceptorChain类。chain.proceed()方法如下。

```java
 @Override public Response proceed(Request request) throws IOException {
    return proceed(request, streamAllocation, httpCodec, connection);
  }

  public Response proceed(Request request, StreamAllocation streamAllocation, HttpCodec httpCodec,
      RealConnection connection) throws IOException {
    if (index >= interceptors.size()) throw new AssertionError();

    calls++;
 
    // Call the next interceptor in the chain.
    RealInterceptorChain next = new RealInterceptorChain(interceptors, streamAllocation, httpCodec,
        connection, index + 1, request, call, eventListener, connectTimeout, readTimeout,
        writeTimeout);
    Interceptor interceptor = interceptors.get(index);
    Response response = interceptor.intercept(next);

    // Confirm that the next interceptor made its required call to chain.proceed().
    if (httpCodec != null && index + 1 < interceptors.size() && next.calls != 1) {
      throw new IllegalStateException("network interceptor " + interceptor
          + " must call proceed() exactly once");
    }

    // Confirm that the intercepted response isn't null.
    if (response == null) {
      throw new NullPointerException("interceptor " + interceptor + " returned null");
    }

    if (response.body() == null) {
      throw new IllegalStateException(
          "interceptor " + interceptor + " returned a response with no body");
    }

    return response;
  }
```
在RealInterceptorChain的Proceed方法中，每次创建一个新的RealInterceptorChain，去拿到拦截器集合中的下一个拦截器，去执行，然后一步一步，一层一层去执行完所有的拦截器，最后拿到返回值。返回回去。有点类似与递归操作。
#### 5.1、RetryAndFollowUpInterceptor拦截器
在RealCall的构造方法中，就新建了一个RetryAndFollowUpInterceptor.
```java
  private RealCall(OkHttpClient client, Request originalRequest, boolean forWebSocket) {
    this.client = client;
    this.originalRequest = originalRequest;
    this.forWebSocket = forWebSocket;
    this.retryAndFollowUpInterceptor = new RetryAndFollowUpInterceptor(client, forWebSocket);
    this.timeout = new AsyncTimeout() {
      @Override protected void timedOut() {
        cancel();
      }
    };
    this.timeout.timeout(client.callTimeoutMillis(), MILLISECONDS);
  }
```
RetryAndFollowUpInterceptor的做用如下：
*  创建StreamAllocation对象，里边有对Http请求的组件
*  调用下一个拦截器
*  根据异常和响应结果判断是不是要重连
*  对response进行处理，返回给上一个拦截器
```java
  //最大重连次数
  private static final int MAX_FOLLOW_UPS = 20;

 @Override public Response intercept(Chain chain) throws IOException {
    Request request = chain.request();
    RealInterceptorChain realChain = (RealInterceptorChain) chain;
    Call call = realChain.call();
    EventListener eventListener = realChain.eventListener();
	//Http请求的内容
    StreamAllocation streamAllocation = new StreamAllocation(client.connectionPool(),
        createAddress(request.url()), call, eventListener, callStackTrace);
    this.streamAllocation = streamAllocation;

    int followUpCount = 0;
    Response priorResponse = null;
    while (true) {
      if (canceled) {
        streamAllocation.release();
        throw new IOException("Canceled");
      }

      Response response;
      boolean releaseConnection = true;
      try {
        response = realChain.proceed(request, streamAllocation, null, null);
        releaseConnection = false;
      } catch (RouteException e) {
        // The attempt to connect via a route failed. The request will not have been sent.
        if (!recover(e.getLastConnectException(), streamAllocation, false, request)) {
          throw e.getFirstConnectException();
        }
        releaseConnection = false;
        continue;
      } catch (IOException e) {
        // An attempt to communicate with a server failed. The request may have been sent.
        boolean requestSendStarted = !(e instanceof ConnectionShutdownException);
        if (!recover(e, streamAllocation, requestSendStarted, request)) throw e;
        releaseConnection = false;
        continue;
      } finally {
        // We're throwing an unchecked exception. Release any resources.
        if (releaseConnection) {
          streamAllocation.streamFailed(null);
          streamAllocation.release();
        }
      }

      // Attach the prior response if it exists. Such responses never have a body.
      //结合当前的response和之前响应的返回后的response
      if (priorResponse != null) {
        response = response.newBuilder()
            .priorResponse(priorResponse.newBuilder()
                    .body(null)
                    .build())
            .build();
      }

      Request followUp;
      try {
        //是否需要重定向(如果不需要，就直接访问)
        followUp = followUpRequest(response, streamAllocation.route());
      } catch (IOException e) {
        streamAllocation.release();
        throw e;
      }

      if (followUp == null) {
        streamAllocation.release();
        return response;
      }

      closeQuietly(response.body());
	 //重定向次数+1，同时判断次数是不是达到了上限，达到上限就释放资源，抛出异常
      if (++followUpCount > MAX_FOLLOW_UPS) {
        streamAllocation.release();
        throw new ProtocolException("Too many follow-up requests: " + followUpCount);
      }

      if (followUp.body() instanceof UnrepeatableRequestBody) {
        streamAllocation.release();
        throw new HttpRetryException("Cannot retry streamed HTTP body", response.code());
      }
	 //检查是否有相同的连接，相同streamAllocation就是释放资源，并且重新构建
      if (!sameConnection(response, followUp.url())) {
        streamAllocation.release();
        streamAllocation = new StreamAllocation(client.connectionPool(),
            createAddress(followUp.url()), call, eventListener, callStackTrace);
        this.streamAllocation = streamAllocation;
      } else if (streamAllocation.codec() != null) {
        throw new IllegalStateException("Closing the body of " + response
            + " didn't close its backing stream. Bad interceptor?");
      }

      request = followUp;
      priorResponse = response;
    }
  }
```
#### 5.2、BridgeInterceptor拦截器

初始化,在getResponseWithInterceptorChain()方法中，初始化了BridgeInterceptor拦截器.
```java
 interceptors.add(new BridgeInterceptor(client.cookieJar()));
```
BridgeInterceptor拦截器的主要作用是设置编码方式，添加请求头，Keep－Alive 连接以及应用层和网络层请求和响应类型之间的相互转换。
* 在发送请求之前给request添加不要的请求头，如Context-Type,Content-Length、Transfer-Encoding等，把request变成可以发送网络请i去的Request
* 执行下一步拦截器，拿到Response
* 将Response转换(Gzip压缩，Gzip解压缩)为用户可以使用的Response.
```java
 @Override public Response intercept(Chain chain) throws IOException {
    Request userRequest = chain.request();
    Request.Builder requestBuilder = userRequest.newBuilder();

    RequestBody body = userRequest.body();
    if (body != null) {
      MediaType contentType = body.contentType();
      if (contentType != null) {
        requestBuilder.header("Content-Type", contentType.toString());
      }

      long contentLength = body.contentLength();
      if (contentLength != -1) {
        requestBuilder.header("Content-Length", Long.toString(contentLength));
        requestBuilder.removeHeader("Transfer-Encoding");
      } else {
        requestBuilder.header("Transfer-Encoding", "chunked");
        requestBuilder.removeHeader("Content-Length");
      }
    }

    if (userRequest.header("Host") == null) {
      requestBuilder.header("Host", hostHeader(userRequest.url(), false));
    }

    if (userRequest.header("Connection") == null) {
      requestBuilder.header("Connection", "Keep-Alive");
    }

    // If we add an "Accept-Encoding: gzip" header field we're responsible for also decompressing
    // the transfer stream.
    boolean transparentGzip = false;
    if (userRequest.header("Accept-Encoding") == null && userRequest.header("Range") == null) {
      transparentGzip = true;
      requestBuilder.header("Accept-Encoding", "gzip");
    }

    List<Cookie> cookies = cookieJar.loadForRequest(userRequest.url());
    if (!cookies.isEmpty()) {
      requestBuilder.header("Cookie", cookieHeader(cookies));
    }

    if (userRequest.header("User-Agent") == null) {
      requestBuilder.header("User-Agent", Version.userAgent());
    }
    //  以上为请求前的头处理
    Response networkResponse = chain.proceed(requestBuilder.build());
    // 以下是请求完成，拿到返回后的头处理
    // 响应header， 如果没有自定义配置cookie不会解析
    //调用Http头部的receiveHeaders静态方法将服务器响应回来的Response转化为用户响应可以使用的Response
    HttpHeaders.receiveHeaders(cookieJar, userRequest.url(), networkResponse.headers());

    Response.Builder responseBuilder = networkResponse.newBuilder()
        .request(userRequest);

    if (transparentGzip
        && "gzip".equalsIgnoreCase(networkResponse.header("Content-Encoding"))
        && HttpHeaders.hasBody(networkResponse)) {
      GzipSource responseBody = new GzipSource(networkResponse.body().source());
      Headers strippedHeaders = networkResponse.headers().newBuilder()
          .removeAll("Content-Encoding")
          .removeAll("Content-Length")
          .build();
      responseBuilder.headers(strippedHeaders);
      String contentType = networkResponse.header("Content-Type");
      responseBuilder.body(new RealResponseBody(contentType, -1L, Okio.buffer(responseBody)));
    }

    return responseBuilder.build();
  }
```
#### 5.3、CacheInterceptor拦截器

初始化,在getResponseWithInterceptorChain()方法中，初始化了CacheInterceptor拦截器.
```java
 interceptors.add(new CacheInterceptor(client.internalCache()));
```
CacheInterceptor拦截器的作用是进行缓存处理
* 执行下一个拦截器
* 拦截器全部执行完毕后，会返回最终响应数据，如果返回结果为空，即无网络，关闭缓存
* 如果cacheResponse缓存不为空，并且最终缓存数据code为304，那就直接在缓存中读取数据
* 有网络，直接返回最终响应数据
* 如果http头部是否有响应体，且策略是可以缓存的，true=将响应体写入Cache,下次直接调用
* 判断最终响应数据是否是无效缓存，true,从Cache清除掉
* 返回response

```java
 @Override public Response intercept(Chain chain) throws IOException {
    //在缓存中拿到Response
    Response cacheCandidate = cache != null
        ? cache.get(chain.request())
        : null;
	//获取系统时间
    long now = System.currentTimeMillis();
    //缓存策略类，该类决定是使用缓存还是进行网络请求
	//根据请求头获取用户指定的缓存策略，并根据缓存策略来获取networkRequest,cacheResoone;
    CacheStrategy strategy = new CacheStrategy.Factory(now, chain.request(), cacheCandidate).get();
    //网络请求，如果为null就代表不进行网络请求
    Request networkRequest = strategy.networkRequest;
    //获取CacheStrategy缓存冲的Response，如果为null,则代表不使用缓存
    Response cacheResponse = strategy.cacheResponse;

    if (cache != null) {
	  //根据缓存策略，更新统计指标：请求次数、使用网络请求次数、使用缓存次数
      cache.trackResponse(strategy);
    }
	
    if (cacheCandidate != null && cacheResponse == null) {
    ////cacheResponse不读缓存，那么cacheCandidate不可用，关闭它
    closeQuietly(cacheCandidate.body()); // The cache candidate wasn't applicable. Close it.
    }

    // If we're forbidden from using the network and the cache is insufficient, fail.
    //如果我们禁止使用网络和缓存不足，则返回504
    if (networkRequest == null && cacheResponse == null) {
      return new Response.Builder()
          .request(chain.request())
          .protocol(Protocol.HTTP_1_1)
          .code(504)
          .message("Unsatisfiable Request (only-if-cached)")
          .body(Util.EMPTY_RESPONSE)
          .sentRequestAtMillis(-1L)
          .receivedResponseAtMillis(System.currentTimeMillis())
          .build();
    }

    // If we don't need the network, we're done.
    //如果不使用网络，且存在缓存，直接返回响应
    if (networkRequest == null) {
      return cacheResponse.newBuilder()
          .cacheResponse(stripBody(cacheResponse))
          .build();
    }

    Response networkResponse = null;
    try {
    //执行下一个拦截器
      networkResponse = chain.proceed(networkRequest);
    } finally {
      // If we're crashing on I/O or otherwise, don't leak the cache body.
      if (networkResponse == null && cacheCandidate != null) {
        closeQuietly(cacheCandidate.body());
      }
    }

    // If we have a cache response too, then we're doing a conditional get.
    if (cacheResponse != null) {
      if (networkResponse.code() == HTTP_NOT_MODIFIED) {
        Response response = cacheResponse.newBuilder()
            .headers(combine(cacheResponse.headers(), networkResponse.headers()))
            .sentRequestAtMillis(networkResponse.sentRequestAtMillis())
            .receivedResponseAtMillis(networkResponse.receivedResponseAtMillis())
            .cacheResponse(stripBody(cacheResponse))
            .networkResponse(stripBody(networkResponse))
            .build();
        networkResponse.body().close();

        // Update the cache after combining headers but before stripping the
        // Content-Encoding header (as performed by initContentStream()).
        cache.trackConditionalCacheHit();
        cache.update(cacheResponse, response);
        return response;
      } else {
        closeQuietly(cacheResponse.body());
      }
    }

    Response response = networkResponse.newBuilder()
        .cacheResponse(stripBody(cacheResponse))
        .networkResponse(stripBody(networkResponse))
        .build();

    if (cache != null) {
      if (HttpHeaders.hasBody(response) && CacheStrategy.isCacheable(response, networkRequest)) {
        // Offer this request to the cache.
        CacheRequest cacheRequest = cache.put(response);
        return cacheWritingResponse(cacheRequest, response);
      }

      if (HttpMethod.invalidatesCache(networkRequest.method())) {
        try {
          cache.remove(networkRequest);
        } catch (IOException ignored) {
          // The cache cannot be written.
        }
      }
    }

    return response;
  }

```
#### 5.4、ConnectInterceptor拦截器
初始化,在getResponseWithInterceptorChain()方法中，初始化了ConnectInterceptor拦截器.
```java
    interceptors.add(new ConnectInterceptor(client));
```
ConnectInterceptor拦截器的作用是建立和服务器的连接
*  ConnectInterceptor获取intercepter传过来的StreamAllocation，treamAllocation.connection()获得连接RealConnection
* 将刚才创建的用于网络io的RealConnection对象，以及对于与服务器交换最为关键的HttpCodec对象传递给后面的拦截器

```java
  @Override public Response intercept(Chain chain) throws IOException {
    RealInterceptorChain realChain = (RealInterceptorChain) chain;
    Request request = realChain.request();
    //这里终于拿到了存储发送请求的类
    StreamAllocation streamAllocation = realChain.streamAllocation();

    // We need the network to satisfy this request. Possibly for validating a conditional GET.
    boolean doExtensiveHealthChecks = !request.method().equals("GET");
    HttpCodec httpCodec = streamAllocation.newStream(client, chain, doExtensiveHealthChecks);
    RealConnection connection = streamAllocation.connection();

    return realChain.proceed(request, streamAllocation, httpCodec, connection);
  }
```

通过newStream拿到发起请求的HttpCodec对象<br>
首先通过findHealthyConnection拿到一个连接，然后通过ResultConnection拿到一个HttpCodec对象

```java
public HttpCodec newStream(
      OkHttpClient client, Interceptor.Chain chain, boolean doExtensiveHealthChecks) {
    int connectTimeout = chain.connectTimeoutMillis();
    int readTimeout = chain.readTimeoutMillis();
    int writeTimeout = chain.writeTimeoutMillis();
    int pingIntervalMillis = client.pingIntervalMillis();
    boolean connectionRetryEnabled = client.retryOnConnectionFailure();

    try {
      RealConnection resultConnection = findHealthyConnection(connectTimeout, readTimeout,
          writeTimeout, pingIntervalMillis, connectionRetryEnabled, doExtensiveHealthChecks);
      HttpCodec resultCodec = resultConnection.newCodec(client, chain, this);

      synchronized (connectionPool) {
        codec = resultCodec;
        return resultCodec;
      }
    } catch (IOException e) {
      throw new RouteException(e);
    }
  }


/**
   * Finds a connection and returns it if it is healthy. If it is unhealthy the process is repeated
   * until a healthy connection is found.
   */
  private RealConnection findHealthyConnection(int connectTimeout, int readTimeout,
      int writeTimeout, int pingIntervalMillis, boolean connectionRetryEnabled,
      boolean doExtensiveHealthChecks) throws IOException {
    while (true) {
      RealConnection candidate = findConnection(connectTimeout, readTimeout, writeTimeout,
          pingIntervalMillis, connectionRetryEnabled);

      // If this is a brand new connection, we can skip the extensive health checks.
      synchronized (connectionPool) {
        if (candidate.successCount == 0) {
          return candidate;
        }
      }

      // Do a (potentially slow) check to confirm that the pooled connection is still good. If it
      // isn't, take it out of the pool and start again.
      if (!candidate.isHealthy(doExtensiveHealthChecks)) {
        noNewStreams();
        continue;
      }

      return candidate;
    }
  }





/**
   * Returns a connection to host a new stream. This prefers the existing connection if it exists,
   * then the pool, finally building a new connection.
   */
  private RealConnection findConnection(int connectTimeout, int readTimeout, int writeTimeout,
      int pingIntervalMillis, boolean connectionRetryEnabled) throws IOException {
    boolean foundPooledConnection = false;
    RealConnection result = null;
    Route selectedRoute = null;
    Connection releasedConnection;
    Socket toClose;
    synchronized (connectionPool) {
      if (released) throw new IllegalStateException("released");
      if (codec != null) throw new IllegalStateException("codec != null");
      if (canceled) throw new IOException("Canceled");

      // Attempt to use an already-allocated connection. We need to be careful here because our
      // already-allocated connection may have been restricted from creating new streams.
      releasedConnection = this.connection;
      toClose = releaseIfNoNewStreams();
        //如果当前的连接可用，就用当前连接返回
      if (this.connection != null) {
        // We had an already-allocated connection and it's good.
        result = this.connection;
        releasedConnection = null;
      }
      if (!reportedAcquired) {
        // If the connection was never reported acquired, don't report it as released!
        releasedConnection = null;
      }

      if (result == null) {
          //如果RealConnection不能复用，就从线程池中取一个
        // Attempt to get a connection from the pool.
        Internal.instance.get(connectionPool, address, this, null);
        if (connection != null) {
          foundPooledConnection = true;
          result = connection;
        } else {
          selectedRoute = route;
        }
      }
    }
    closeQuietly(toClose);

    if (releasedConnection != null) {
      eventListener.connectionReleased(call, releasedConnection);
    }
    if (foundPooledConnection) {
      eventListener.connectionAcquired(call, result);
    }
    if (result != null) {
      // If we found an already-allocated or pooled connection, we're done.
      return result;
    }

    // If we need a route selection, make one. This is a blocking operation.
    boolean newRouteSelection = false;
    if (selectedRoute == null && (routeSelection == null || !routeSelection.hasNext())) {
      newRouteSelection = true;
      routeSelection = routeSelector.next();
    }

    synchronized (connectionPool) {
      if (canceled) throw new IOException("Canceled");

      if (newRouteSelection) {
        // Now that we have a set of IP addresses, make another attempt at getting a connection from
        // the pool. This could match due to connection coalescing.
	   //遍历所有路由地址，再次尝试从ConnectionPool中获取
        List<Route> routes = routeSelection.getAll();
        for (int i = 0, size = routes.size(); i < size; i++) {
          Route route = routes.get(i);
          Internal.instance.get(connectionPool, address, this, route);
          if (connection != null) {
            foundPooledConnection = true;
            result = connection;
            this.route = route;
            break;
          }
        }
      }

      if (!foundPooledConnection) {
        if (selectedRoute == null) {
          selectedRoute = routeSelection.next();
        }

        // Create a connection and assign it to this allocation immediately. This makes it possible
        // for an asynchronous cancel() to interrupt the handshake we're about to do.
        route = selectedRoute;
        refusedStreamCount = 0;
        //创建一个新的
        result = new RealConnection(connectionPool, selectedRoute);
        acquire(result, false);
      }
    }

    // If we found a pooled connection on the 2nd time around, we're done.
    if (foundPooledConnection) {
      eventListener.connectionAcquired(call, result);
      return result;
    }

    // Do TCP + TLS handshakes. This is a blocking operation.
    //这里进行实际网络连接
    result.connect(connectTimeout, readTimeout, writeTimeout, pingIntervalMillis,
        connectionRetryEnabled, call, eventListener);
    routeDatabase().connected(result.route());

    Socket socket = null;
    synchronized (connectionPool) {
      reportedAcquired = true;

      // Pool the connection.
      //获取成功后把链接放入连接池中
      Internal.instance.put(connectionPool, result);

      // If another multiplexed connection to the same address was created concurrently, then
      // release this connection and acquire that one.
      if (result.isMultiplexed()) {
        socket = Internal.instance.deduplicate(connectionPool, address, this);
        result = connection;
      }
    }
    closeQuietly(socket);

    eventListener.connectionAcquired(call, result);
    return result;
  }

```

* 1、首先判断StreamAllocation对象是否在Connection对象，有就返回(复用)
* 2、如果1步骤中没有拿到，就去ConnectionPool中获取
* 3、如果2没拿到，就去遍历所有的路由地址，并在此从ConnectionPool中获取
* 4、如果3没拿到，就创建一个新的
* 5、最后把拿到的Connection对象放到ConnectionPool中

在newCodec方法中，我们看到了对Http1.1和Http2 的构建

```java
 public HttpCodec newCodec(OkHttpClient client, Interceptor.Chain chain,
      StreamAllocation streamAllocation) throws SocketException {
    if (http2Connection != null) {
      return new Http2Codec(client, chain, streamAllocation, http2Connection);
    } else {
      socket.setSoTimeout(chain.readTimeoutMillis());
      source.timeout().timeout(chain.readTimeoutMillis(), MILLISECONDS);
      sink.timeout().timeout(chain.writeTimeoutMillis(), MILLISECONDS);
      return new Http1Codec(client, streamAllocation, source, sink);
    }
  }
```

然后看一个Connection被放入Connection中之后做了什么，就是在findConnection()方法调用的

```java
      Internal.instance.put(connectionPool, result);
```

调用的是ConnectionPool类的put方法

```java
  void put(RealConnection connection) {
    assert (Thread.holdsLock(this));
    if (!cleanupRunning) {
      cleanupRunning = true;
        //异步清理回收线程
      executor.execute(cleanupRunnable);
    }
      //接入链接队列
    connections.add(connection);
  }
```

在加入连接队列之前，先执行了cleanupRunnable线程，这个线程在做什么？

```java
  /** The maximum number of idle connections for each address. */
  private final int maxIdleConnections;
  private final long keepAliveDurationNs;
  private final Runnable cleanupRunnable = new Runnable() {
    @Override public void run() {
      while (true) {
          //下次清理的间隔时间
        long waitNanos = cleanup(System.nanoTime());
        if (waitNanos == -1) return;
        if (waitNanos > 0) {
          long waitMillis = waitNanos / 1000000L;
          waitNanos -= (waitMillis * 1000000L);
          synchronized (ConnectionPool.this) {
            try {
                //等待释放锁和时间间隔
              ConnectionPool.this.wait(waitMillis, (int) waitNanos);
            } catch (InterruptedException ignored) {
            }
          }
        }
      }
    }
  };
```

具体如何清理的都在cleanup方法里边

```java
/**
   * Performs maintenance on this pool, evicting the connection that has been idle the longest if
   * either it has exceeded the keep alive limit or the idle connections limit.
   *
   * <p>Returns the duration in nanos to sleep until the next scheduled call to this method. Returns
   * -1 if no further cleanups are required.
   * 返回-1，则不需要清理
   */
  long cleanup(long now) {
      //活跃链接数
    int inUseConnectionCount = 0;
	//空闲连接数量
    int idleConnectionCount = 0;
    RealConnection longestIdleConnection = null;
    long longestIdleDurationNs = Long.MIN_VALUE;

    // Find either a connection to evict, or the time that the next eviction is due.
    synchronized (this) {
        //遍历所有的Connection
      for (Iterator<RealConnection> i = connections.iterator(); i.hasNext(); ) {
        RealConnection connection = i.next();

        // If the connection is in use, keep searching.
		//正在使用，inUseConnectionCount+1，然后跳出当前循环，继续
        if (pruneAndGetAllocationCount(connection, now) > 0) {
          inUseConnectionCount++;
          continue;
        }
		//否者，空闲连接+1
        idleConnectionCount++;

        // If the connection is ready to be evicted, we're done.
        long idleDurationNs = now - connection.idleAtNanos;
        if (idleDurationNs > longestIdleDurationNs) {
          longestIdleDurationNs = idleDurationNs;
          longestIdleConnection = connection;
        }
      }

      if (longestIdleDurationNs >= this.keepAliveDurationNs
          || idleConnectionCount > this.maxIdleConnections) {
          //如果空闲连接空闲时间超过5min||空闲连接数量大于5个，就移除这个链接
        // We've found a connection to evict. Remove it from the list, then close it below (outside
        // of the synchronized block).
        connections.remove(longestIdleConnection);
      } else if (idleConnectionCount > 0) {
          //如果上面处理返回的空闲连接数大于0，就返回保活时间与空闲时间差
        // A connection will be ready to evict soon.
        return keepAliveDurationNs - longestIdleDurationNs;
      } else if (inUseConnectionCount > 0) {
		//如果上面处理返回的都是活跃(正在)链接，就返回保活时间
        // All connections are in use. It'll be at least the keep alive duration 'til we run again.
        return keepAliveDurationNs;
      } else {
		//如果没有链接，就不用清理了
        // No connections, idle or in use.
        cleanupRunning = false;
        return -1;
      }
    }

    closeQuietly(longestIdleConnection.socket());

    // Cleanup again immediately.
    return 0;
  }
```

* 1、循环遍历所有的connection队列，如果当前connection正在被使用，那么活跃连接数+1，跳出当前逻辑，执行下一次逻辑，否则，空闲连接数+1；
* 2、继续，当前空闲连接connection对象的空闲时间比已知时间长，就记录下来
* 3、如果空闲连接的时间超过5分钟，或者空闲连接数量大于5个，就移除这个链接
* 4、如果条件3不满足，判断空闲数量是否大于0.就返回保活时间与空闲时间差，就是还有多久就超过5min了
* 5、如果4也不满足，就是没有孔祥连接，就判断有没有正在使用的连接，如果有，就返回下一次清理时间为Connection的保活时间
* 6、如果5也不满足，就是也没有正在使用的连接，也没用空闲连接，那就返回-1，不用清理线程池了。



#### 5.5、CallServerInterceptor拦截器

初始化,在getResponseWithInterceptorChain()方法中，初始化了CallServerInterceptor拦截器.

```Java
 interceptors.add(new CallServerInterceptor(forWebSocket));
```

CallServerInterceptor拦截器的作用就是发起网络请求和服务器返回响应

```Java
@Override public Response intercept(Chain chain) throws IOException {
    //拦截器链
    RealInterceptorChain realChain = (RealInterceptorChain) chain;
    //拿到用来收发数据的组件流对象
    HttpCodec httpCodec = realChain.httpStream();
    //用来HTTP请求所需要的组建
    StreamAllocation streamAllocation = realChain.streamAllocation();
    //Connection类的具体实现
    RealConnection connection = (RealConnection) realChain.connection();
    //请求体
    Request request = realChain.request();

    long sentRequestMillis = System.currentTimeMillis();

    realChain.eventListener().requestHeadersStart(realChain.call());
    //先向Socket中写入请求头信息
    httpCodec.writeRequestHeaders(request);
    realChain.eventListener().requestHeadersEnd(realChain.call(), request);

    Response.Builder responseBuilder = null;
   
    //检查是否有请求体
    if (HttpMethod.permitsRequestBody(request.method()) && request.body() != null) {
      // If there's a "Expect: 100-continue" header on the request, wait for a "HTTP/1.1 100
      // Continue" response before transmitting the request body. If we don't get that, return
      // what we did get (such as a 4xx response) without ever transmitting the request body.
        //特殊处理，如果服务器允许请求头可以携带Expect或100-continue字段，直接获取响应信息
	   //通过“100-continue”请求头询问服务器是否可以发送携带请求体的信息
      if ("100-continue".equalsIgnoreCase(request.header("Expect"))) {
        httpCodec.flushRequest();
        realChain.eventListener().responseHeadersStart(realChain.call());
        responseBuilder = httpCodec.readResponseHeaders(true);
      }

       //允许携带请求体，就写入请求体 
      if (responseBuilder == null) {
        // Write the request body if the "Expect: 100-continue" expectation was met.
        realChain.eventListener().requestBodyStart(realChain.call());
        long contentLength = request.body().contentLength();
        CountingSink requestBodyOut =
            new CountingSink(httpCodec.createRequestBody(request, contentLength));
        BufferedSink bufferedRequestBody = Okio.buffer(requestBodyOut);
		//向Socket写入请求体
        request.body().writeTo(bufferedRequestBody);
        bufferedRequestBody.close();
        realChain.eventListener()
            .requestBodyEnd(realChain.call(), requestBodyOut.successfulCount);
      } else if (!connection.isMultiplexed()) {
        // If the "Expect: 100-continue" expectation wasn't met, prevent the HTTP/1 connection
        // from being reused. Otherwise we're still obligated to transmit the request body to
        // leave the connection in a consistent state.
        streamAllocation.noNewStreams();
      }
    }
	//完成网络请求写入
    httpCodec.finishRequest();

    if (responseBuilder == null) {
      realChain.eventListener().responseHeadersStart(realChain.call());
      //读取响应头
      responseBuilder = httpCodec.readResponseHeaders(false);
    }

    //构建响应体
    Response response = responseBuilder
        .request(request)
        .handshake(streamAllocation.connection().handshake())
        .sentRequestAtMillis(sentRequestMillis)
        .receivedResponseAtMillis(System.currentTimeMillis())
        .build();

    int code = response.code();
    if (code == 100) {
      // server sent a 100-continue even though we did not request one.
      // try again to read the actual response
      responseBuilder = httpCodec.readResponseHeaders(false);
		
      response = responseBuilder
              .request(request)
              .handshake(streamAllocation.connection().handshake())
              .sentRequestAtMillis(sentRequestMillis)
              .receivedResponseAtMillis(System.currentTimeMillis())
              .build();

      code = response.code();
    }

    realChain.eventListener()
            .responseHeadersEnd(realChain.call(), response);

    if (forWebSocket && code == 101) {
        //返回无效响应
      // Connection is upgrading, but we need to ensure interceptors see a non-null response body.
      response = response.newBuilder()
          .body(Util.EMPTY_RESPONSE)
          .build();
    } else {
      response = response.newBuilder()
          //读取服务器的响应体及内容
          .body(httpCodec.openResponseBody(response))
          .build();
    }

    if ("close".equalsIgnoreCase(response.request().header("Connection"))
        || "close".equalsIgnoreCase(response.header("Connection"))) {
      streamAllocation.noNewStreams();
    }

    if ((code == 204 || code == 205) && response.body().contentLength() > 0) {
      throw new ProtocolException(
          "HTTP " + code + " had non-zero Content-Length: " + response.body().contentLength());
    }

    return response;
  }
```



* 1、首先初始化对象，调用httpCodec.writeRequestHeaders(request);写入请求头
* 2、询问服务器是否可以发送请求体
* 3、当前面的“100-continue”，需要握手，但是握手失败，如果body信息为空，并写入请求体，判断多路复用，关闭写入流和Connection
* 4、完成网络请求写入
* 5、判断body是否为空，如果为空，就直接读取响应的头部信息，并写入一个原请求，握手情况及时间，得到时间的Response
* 6、读取body信息
* 7、如果设置了连接colse，断开连接，关闭写入流和Connection
* 8、返回Response

到这里整个请求过程就结束了.