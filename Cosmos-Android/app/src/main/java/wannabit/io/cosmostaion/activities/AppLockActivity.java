package wannabit.io.cosmostaion.activities;

import android.annotation.TargetApi;
import android.app.Activity;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.support.v4.app.FragmentManager;
import android.support.v4.app.FragmentPagerAdapter;
import android.support.v4.hardware.fingerprint.FingerprintManagerCompat;
import android.support.v4.os.CancellationSignal;
import android.view.View;
import android.view.animation.Animation;
import android.view.animation.AnimationUtils;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import java.util.ArrayList;

import wannabit.io.cosmostaion.R;
import wannabit.io.cosmostaion.base.BaseActivity;
import wannabit.io.cosmostaion.fragment.AlphabetKeyBoardFragment;
import wannabit.io.cosmostaion.fragment.KeyboardFragment;
import wannabit.io.cosmostaion.fragment.NumberKeyBoardFragment;
import wannabit.io.cosmostaion.task.TaskListener;
import wannabit.io.cosmostaion.task.TaskResult;
import wannabit.io.cosmostaion.task.UserTask.CheckPasswordTask;
import wannabit.io.cosmostaion.utils.KeyboardListener;
import wannabit.io.cosmostaion.utils.WUtil;
import wannabit.io.cosmostaion.widget.StopViewPager;

public class AppLockActivity extends BaseActivity implements KeyboardListener, TaskListener {

    private LinearLayout            mLayerContents;
    private ImageView               mFingerImage;
    private TextView                mUnlockMsg;
    private ImageView[]             mIvCircle = new ImageView[5];

    private StopViewPager           mViewPager;
    private KeyboardPagerAdapter    mAdapter;
    private String                  mUserInput = "";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_applock);
        mLayerContents  = findViewById(R.id.layer_contents);
        mFingerImage    = findViewById(R.id.img_fingerprint);
        mUnlockMsg      = findViewById(R.id.tv_unlock_msg);
        mViewPager      = findViewById(R.id.pager_keyboard);
        mNeedLeaveTime = false;

        for(int i = 0; i < mIvCircle.length; i++) {
            mIvCircle[i] = findViewById(getResources().getIdentifier("img_circle" + i , "id", getPackageName()));
        }

        mViewPager.setOffscreenPageLimit(2);
        mAdapter = new KeyboardPagerAdapter(getSupportFragmentManager());
        mViewPager.setAdapter(mAdapter);

        onInitView();
    }

    private void onInitView() {
        mUserInput = "";
        for(int i = 0; i < mIvCircle.length; i++) {
            mIvCircle[i].setBackground(getDrawable(R.drawable.ic_pass_gr));
        }
        mViewPager.setCurrentItem(0, true);
        onCheckFingerPrint();
    }

    @Override
    public void onBackPressed() {
        Intent intent = new Intent();
        intent.setAction(Intent.ACTION_MAIN);
        intent.addCategory(Intent.CATEGORY_HOME);
        startActivity(intent);
    }

    private void onUnlock() {
        setResult(Activity.RESULT_OK, new Intent());
        finish();
        overridePendingTransition(R.anim.fade_in, R.anim.slide_out_bottom);
    }

    @TargetApi(Build.VERSION_CODES.M)
    private void onCheckFingerPrint() {
        FingerprintManagerCompat mFingerprintManagerCompat = FingerprintManagerCompat.from(this);
        if ((Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) &&
                mFingerprintManagerCompat.isHardwareDetected() &&
                mFingerprintManagerCompat.hasEnrolledFingerprints() &&
                getBaseDao().getUsingFingerPrint()) {
            mFingerImage.setVisibility(View.VISIBLE);
            mUnlockMsg.setText(R.string.str_app_unlock_msg2);

            mFingerprintManagerCompat.authenticate(null, 0, new CancellationSignal(), new FingerprintManagerCompat.AuthenticationCallback() {
                @Override
                public void onAuthenticationError(int errMsgId, CharSequence errString) {
                    super.onAuthenticationError(errMsgId, errString);
                    Toast.makeText(getBaseContext(), errString, Toast.LENGTH_SHORT).show();
                }

                @Override
                public void onAuthenticationHelp(int helpMsgId, CharSequence helpString) {
                    mUnlockMsg.setText(helpString);
                    super.onAuthenticationHelp(helpMsgId, helpString);
                }

                @Override
                public void onAuthenticationSucceeded(FingerprintManagerCompat.AuthenticationResult result) {
                    super.onAuthenticationSucceeded(result);
                    onUnlock();
                }

                @Override
                public void onAuthenticationFailed() {
                    super.onAuthenticationFailed();
                }
            }, null);

        } else {
            mFingerImage.setVisibility(View.GONE);
            mUnlockMsg.setText(R.string.str_app_unlock_msg1);
        }
    }

    @Override
    public void userInsertKey(char input) {
        if(mUserInput == null || mUserInput.length() == 0) {
            mUserInput = String.valueOf(input);

        } else if (mUserInput.length() < 5) {
            mUserInput = mUserInput + input;
        }

        if (mUserInput.length() == 4) {
            mViewPager.setCurrentItem(1, true);

        } else if (mUserInput.length() == 5 && WUtil.checkPasscodePattern(mUserInput)) {
            onFinishInput();

        } else if (mUserInput.length() == 5 && !WUtil.checkPasscodePattern(mUserInput)) {
            onInitView();
            return;
        }
        onUpdateCnt();
    }

    @Override
    public void userDeleteKey() {
        if(mUserInput == null || mUserInput.length() <= 0) {
            onBackPressed();
        } else if (mUserInput.length() == 4) {
            mUserInput = mUserInput.substring(0, mUserInput.length()-1);
            mViewPager.setCurrentItem(0, true);
        } else {
            mUserInput = mUserInput.substring(0, mUserInput.length()-1);
        }
        onUpdateCnt();
    }

    private void onFinishInput() {
        onShowWaitDialog();
        new CheckPasswordTask(getBaseApplication(), this).execute(mUserInput);
    }

    private void onUpdateCnt() {
        if(mUserInput == null)
            mUserInput = "";

        final int inputLength = mUserInput.length();
        for(int i = 0; i < mIvCircle.length; i++) {
            if(i < inputLength)
                mIvCircle[i].setBackground(getDrawable(R.drawable.ic_pass_pu));
            else
                mIvCircle[i].setBackground(getDrawable(R.drawable.ic_pass_gr));
        }
    }

    private void onShakeView() {
        mLayerContents.clearAnimation();
        Animation animation = AnimationUtils.loadAnimation(this, R.anim.shake);
        animation.reset();
        animation.setAnimationListener(new Animation.AnimationListener() {
            @Override
            public void onAnimationStart(Animation animation) { }

            @Override
            public void onAnimationEnd(Animation animation) {
                onInitView();
            }

            @Override
            public void onAnimationRepeat(Animation animation) { }
        });
        mLayerContents.startAnimation(animation);
    }


//    @Override
//    protected void onStop() {
//        super.onStop();
//        finish();
//    }

    @Override
    public void onTaskResponse(TaskResult result) {
        if(isFinishing()) return;
        onHideWaitDialog();
        if(result.isSuccess) {
            onUnlock();
        } else {
            onShakeView();
            onInitView();
            Toast.makeText(getBaseContext(), getString(R.string.error_invalid_password), Toast.LENGTH_SHORT).show();
        }
    }



    public class KeyboardPagerAdapter extends FragmentPagerAdapter {

        private ArrayList<KeyboardFragment> mFragments = new ArrayList<>();

        public KeyboardPagerAdapter(FragmentManager fm) {
            super(fm);
            mFragments.clear();
            NumberKeyBoardFragment number = NumberKeyBoardFragment.newInstance();
            number.setListener(AppLockActivity.this);
            mFragments.add(number);

            AlphabetKeyBoardFragment alphabet = AlphabetKeyBoardFragment.newInstance();
            alphabet.setListener(AppLockActivity.this);
            mFragments.add(alphabet);
        }

        @Override
        public Fragment getItem(int position) {
            return mFragments.get(position);
        }

        @Override
        public int getCount() {
            return mFragments.size();
        }

        public ArrayList<KeyboardFragment> getFragments() {
            return mFragments;
        }
    }
}
