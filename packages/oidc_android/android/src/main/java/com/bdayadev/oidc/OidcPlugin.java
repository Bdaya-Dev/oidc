package com.bdayadev.oidc;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public final class OidcPlugin implements FlutterPlugin, MethodCallHandler {
    @Nullable
    private MethodChannel channel;
    @Nullable 
    private Context context;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        channel = new MethodChannel(binding.getBinaryMessenger(), "oidc_android");
        channel.setMethodCallHandler(this);
        context = binding.getApplicationContext();
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        if (call.method.equals("getPlatformName")) {
            result.success("Android");
        } else {
            result.notImplemented();
        }
    }

      @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (channel!=null) {
            channel.setMethodCallHandler(null);
        }
        context = null;
    }
}