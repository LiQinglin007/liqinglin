## 使用流程
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
```
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

```
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
```
  /**
   * Prepares the {@code request} to be executed at some point in the future.
   */
  @Override public Call newCall(Request request) {
    return RealCall.newRealCall(this, request, false /* for web socket */);
  }

```
Call类只是一个接口，具体的实现在RealCall类中。
```
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
```
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


```
  /** Running synchronous calls. Includes canceled calls that haven't finished yet. */
  //同步执行队列
  private final Deque<RealCall> runningSyncCalls = new ArrayDeque<>();

 /** Used by {@code Call#execute} to signal it is in-flight. */
  synchronized void executed(RealCall call) {
    runningSyncCalls.add(call);
  }
```
Dispatcher.executed()方法就把Call添加到同步执行队列中。<br>
每次调用executed()方法时，Dispatcher会帮我们把同步请求添加到同步请求队列中，Dispatcher的作用就是维持Call请求状态和维护线程池，并把Call请求到相应的请求队列中，有请求队列决定当前Call请求是等待还是直接执行。

在请求结束后，执行Dispatcher().finished()方法
```
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
```
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
```
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
```
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
```
  /** Running asynchronous calls. Includes canceled calls that haven't finished yet. */
  //异步执行队列
  private final Deque<AsyncCall> runningAsyncCalls = new ArrayDeque<>();
```
这个AsyncCall是个什么东西呢？
```
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

```
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
```
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
这里Interceptor也是一个接口，实现类在RealInterceptorChain类。chain.proceed()方法如下。
```
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
```
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
```
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
```
 interceptors.add(new BridgeInterceptor(client.cookieJar()));
```
BridgeInterceptor拦截器的主要作用是设置编码方式，添加请求头，Keep－Alive 连接以及应用层和网络层请求和响应类型之间的相互转换。
* 在发送请求之前给request添加不要的请求头，如Context-Type,Content-Length、Transfer-Encoding等，把request变成可以发送网络请i去的Request
* 执行下一步拦截器，拿到Response
* 将Response转换(Gzip压缩，Gzip解压缩)为用户可以使用的Response.
```
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
```
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

```
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
```
    interceptors.add(new ConnectInterceptor(client));
```
ConnectInterceptor拦截器的作用是建立和服务器的连接
*  ConnectInterceptor获取intercepter传过来的StreamAllocation，treamAllocation.connection()获得连接RealConnection
* 将刚才创建的用于网络io的RealConnection对象，以及对于与服务器交换最为关键的HttpCodec对象传递给后面的拦截器
 
```
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

```
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
```





















