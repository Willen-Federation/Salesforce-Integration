import { createElement } from 'lwc';
import PortalSetupWizard from 'c/portalSetupWizard';

// テスト対象のコンポーネントが呼び出すApexメソッドをモックする
import getPortalConfig from '@salesforce/apex/PortalConfigController.getPortalConfig';
import getSchedulerStatus from '@salesforce/apex/PortalSchedulerController.getSchedulerStatus';

// Jestに、指定されたApexメソッドをモックするよう指示
jest.mock(
    '@salesforce/apex/PortalConfigController.getPortalConfig',
    () => ({ default: jest.fn() }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/PortalSchedulerController.getSchedulerStatus',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

describe('c-portal-setup-wizard', () => {
    // 各テストの後にDOMをクリーンアップし、モックをリセットする
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    // 非同期処理（Apex呼び出しなど）の完了を待つためのヘルパー関数
    async function flushPromises() {
        return new Promise(resolve => setTimeout(resolve, 0));
    }

    it('初期表示時に "welcome" ステップが表示されること', async () => {
        // 準備: Apexモックの戻り値を設定
        getPortalConfig.mockResolvedValue({});
        getSchedulerStatus.mockResolvedValue({ isScheduled: false });

        const element = createElement('c-portal-setup-wizard', {
            is: PortalSetupWizard
        });

        // 実行: コンポーネントをDOMに追加
        document.body.appendChild(element);
        await flushPromises(); // connectedCallback内の非同期処理を待つ

        // 検証: 進捗コンポーネントの currentStep が welcome であることを確認
        const progress = element.shadowRoot.querySelector('lightning-progress-indicator');
        expect(progress.currentStep).toBe('welcome');
    });

    it('「次へ」ボタンクリックで "basic" ステップに遷移すること', async () => {
        // 準備
        getPortalConfig.mockResolvedValue({});
        getSchedulerStatus.mockResolvedValue({ isScheduled: false });

        const element = createElement('c-portal-setup-wizard', {
            is: PortalSetupWizard
        });
        document.body.appendChild(element);
        await flushPromises();

        // バリデーション処理をモックして、常に成功するようにする
        element.validateCurrentStep = jest.fn(() => true);

        // 実行: 「次へ」ボタンを探してクリック
        const nextButton = [...element.shadowRoot.querySelectorAll('lightning-button')]
            .find(button => button.label === '次へ');
        expect(nextButton).toBeTruthy();
        nextButton.click();
        await flushPromises(); // 状態変更と再描画を待つ

        // 検証: 進捗コンポーネントの currentStep が basic に変わったことを確認
        const progress = element.shadowRoot.querySelector('lightning-progress-indicator');
        expect(progress.currentStep).toBe('basic');
    });
});
