/**
 * 一括通知配信コントローラー。
 * CSV テンプレートの生成・パース・プレビュー・送信を管理する。
 */
public with sharing class BulkNotificationController {

    // システム定義列（Member__c から自動入力）
    private static final List<String> SYSTEM_COLUMNS = new List<String>{
        '会員ID', '会員番号', '姓', '名', 'メールアドレス', '会員種別', '会員ステータス'
    };

    // ----------------------------------------------------------------
    // テンプレートCSV生成
    // ----------------------------------------------------------------

    @AuraEnabled
    public static String generateTemplateCsv(List<String> customFields, String memberTypeFilter) {
        List<Member__c> members = queryMembers(memberTypeFilter);

        List<String> allColumns = new List<String>(SYSTEM_COLUMNS);
        if (customFields != null) {
            for (String cf : customFields) {
                if (String.isNotBlank(cf)) allColumns.add(cf.trim());
            }
        }

        List<String> lines = new List<String>();
        lines.add(buildCsvRow(allColumns));

        for (Member__c m : members) {
            List<String> row = new List<String>{
                m.Id,
                m.Name,
                m.LastName__c  ?? '',
                m.FirstName__c ?? '',
                m.Email__c     ?? '',
                m.MemberType__c   ?? '',
                m.MemberStatus__c ?? ''
            };
            // カスタム列は空欄
            if (customFields != null) {
                for (String cf : customFields) {
                    if (String.isNotBlank(cf)) row.add('');
                }
            }
            lines.add(buildCsvRow(row));
        }

        // UTF-8 BOM + CRLF（Excel対応）
        return '﻿' + String.join(lines, '\r\n');
    }

    // ----------------------------------------------------------------
    // CSVパース
    // ----------------------------------------------------------------

    @AuraEnabled
    public static List<Map<String, String>> parseCsv(String csvContent) {
        if (String.isBlank(csvContent)) return new List<Map<String, String>>();

        // BOM 除去
        String content = csvContent.startsWith('﻿')
            ? csvContent.substring(1) : csvContent;

        // 改行コード正規化
        content = content.replace('\r\n', '\n').replace('\r', '\n');
        List<String> rawLines = content.split('\n');

        if (rawLines.isEmpty()) return new List<Map<String, String>>();

        List<String> headers = parseCsvLine(rawLines[0]);
        List<Map<String, String>> result = new List<Map<String, String>>();

        for (Integer i = 1; i < rawLines.size(); i++) {
            String line = rawLines[i];
            if (String.isBlank(line)) continue;
            List<String> values = parseCsvLine(line);
            Map<String, String> row = new Map<String, String>();
            for (Integer j = 0; j < headers.size(); j++) {
                row.put(headers[j], j < values.size() ? values[j] : '');
            }
            result.add(row);
        }
        return result;
    }

    // ----------------------------------------------------------------
    // メッセージプレビュー（先頭5件）
    // ----------------------------------------------------------------

    @AuraEnabled
    public static List<PreviewItem> renderPreview(String subjectTemplate, String bodyTemplate, String rowsJson) {
        List<Object> rawRows = (List<Object>) JSON.deserializeUntyped(rowsJson);
        List<PreviewItem> result = new List<PreviewItem>();
        Integer limit = Math.min(rawRows.size(), 5);

        for (Integer i = 0; i < limit; i++) {
            Map<String, Object> row = (Map<String, Object>) rawRows[i];
            Map<String, String> strRow = new Map<String, String>();
            for (String k : row.keySet()) {
                strRow.put(k, String.valueOf(row.get(k) ?? ''));
            }
            PreviewItem item = new PreviewItem();
            item.recipientName  = (strRow.get('姓') ?? '') + ' ' + (strRow.get('名') ?? '');
            item.recipientEmail = strRow.get('メールアドレス') ?? '';
            item.subject        = mergePlaceholders(subjectTemplate, strRow);
            item.body           = mergePlaceholders(bodyTemplate, strRow);
            result.add(item);
        }
        return result;
    }

    // ----------------------------------------------------------------
    // 一括送信
    // ----------------------------------------------------------------

    @AuraEnabled
    public static NotificationResult sendBulkNotifications(
            String subjectTemplate, String bodyTemplate,
            String rowsJson, String channels) {

        List<Object> rawRows = (List<Object>) JSON.deserializeUntyped(rowsJson);
        Boolean doEmail = channels == null || channels.contains('email');
        Boolean doSlack = channels != null && channels.contains('slack');

        PortalConfiguration__c config = PortalConfiguration__c.getOrgDefaults();

        NotificationResult res = new NotificationResult();
        res.successCount = 0;
        res.failCount    = 0;
        res.errors       = new List<String>();

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Object rawRow : rawRows) {
            Map<String, Object> rawMap = (Map<String, Object>) rawRow;
            Map<String, String> row = new Map<String, String>();
            for (String k : rawMap.keySet()) {
                row.put(k, String.valueOf(rawMap.get(k) ?? ''));
            }

            String toEmail = row.get('メールアドレス') ?? '';
            if (String.isBlank(toEmail)) {
                res.failCount++;
                res.errors.add((row.get('姓') ?? '(不明)') + ': メールアドレスが空です');
                continue;
            }

            try {
                String subject = mergePlaceholders(subjectTemplate, row);
                String body    = mergePlaceholders(bodyTemplate, row);

                if (doEmail) {
                    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                    email.setToAddresses(new List<String>{ toEmail });
                    email.setSubject(subject);
                    email.setPlainTextBody(body);
                    if (String.isNotBlank(config?.FromEmailAddress__c)) {
                        email.setSenderDisplayName(config.OrganizationName__c ?? '');
                        email.setReplyTo(config.FromEmailAddress__c);
                    }
                    emails.add(email);
                }
                res.successCount++;
            } catch (Exception e) {
                res.failCount++;
                res.errors.add(toEmail + ': ' + e.getMessage());
            }
        }

        if (doEmail && !emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails);
            } catch (Exception e) {
                res.failCount    += emails.size();
                res.successCount -= emails.size();
                res.errors.add('メール送信エラー: ' + e.getMessage());
            }
        }

        if (doSlack && String.isNotBlank(config?.SupportSlackChannelId__c)) {
            sendSlackSummaryAsync(config.SupportSlackChannelId__c, res.successCount, subjectTemplate);
        }

        return res;
    }

    // ----------------------------------------------------------------
    // 会員一覧取得
    // ----------------------------------------------------------------

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getMemberTypeOptions() {
        List<Map<String, String>> opts = new List<Map<String, String>>();
        opts.add(new Map<String, String>{ 'label' => '全会員', 'value' => '' });
        Schema.DescribeFieldResult fr = Member__c.MemberType__c.getDescribe();
        for (Schema.PicklistEntry pe : fr.getPicklistValues()) {
            if (pe.isActive()) {
                opts.add(new Map<String, String>{ 'label' => pe.getLabel(), 'value' => pe.getValue() });
            }
        }
        return opts;
    }

    // ----------------------------------------------------------------
    // Private helpers
    // ----------------------------------------------------------------

    private static List<Member__c> queryMembers(String memberTypeFilter) {
        if (String.isNotBlank(memberTypeFilter)) {
            return [
                SELECT Id, Name, LastName__c, FirstName__c, Email__c,
                       MemberType__c, MemberStatus__c
                FROM Member__c
                WHERE MemberType__c = :memberTypeFilter
                  AND MemberStatus__c != '退会'
                WITH SECURITY_ENFORCED
                ORDER BY Name
                LIMIT 2000
            ];
        }
        return [
            SELECT Id, Name, LastName__c, FirstName__c, Email__c,
                   MemberType__c, MemberStatus__c
            FROM Member__c
            WHERE MemberStatus__c != '退会'
            WITH SECURITY_ENFORCED
            ORDER BY Name
            LIMIT 2000
        ];
    }

    private static String buildCsvRow(List<String> values) {
        List<String> escaped = new List<String>();
        for (String v : values) {
            String val = v ?? '';
            // ダブルクォート・カンマ・改行を含む場合はクォート
            if (val.contains('"') || val.contains(',') || val.contains('\n') || val.contains('\r')) {
                escaped.add('"' + val.replace('"', '""') + '"');
            } else {
                escaped.add(val);
            }
        }
        return String.join(escaped, ',');
    }

    private static List<String> parseCsvLine(String line) {
        List<String> fields = new List<String>();
        Integer i = 0;
        Integer len = line.length();
        while (i <= len) {
            if (i == len) { fields.add(''); break; }
            String ch = line.substring(i, i + 1);
            if (ch == '"') {
                // クォートフィールド
                i++;
                String field = '';
                while (i < len) {
                    String c = line.substring(i, i + 1);
                    if (c == '"') {
                        if (i + 1 < len && line.substring(i + 1, i + 2) == '"') {
                            field += '"';
                            i += 2;
                        } else {
                            i++;
                            break;
                        }
                    } else {
                        field += c;
                        i++;
                    }
                }
                fields.add(field);
                if (i < len && line.substring(i, i + 1) == ',') i++;
            } else {
                Integer commaIdx = line.indexOf(',', i);
                if (commaIdx == -1) {
                    fields.add(line.substring(i));
                    break;
                }
                fields.add(line.substring(i, commaIdx));
                i = commaIdx + 1;
                if (i == len) { fields.add(''); break; }
            }
        }
        return fields;
    }

    private static String mergePlaceholders(String template, Map<String, String> row) {
        if (String.isBlank(template)) return '';
        String result = template;
        for (String key : row.keySet()) {
            result = result.replace('{!' + key + '}', row.get(key) ?? '');
        }
        return result;
    }

    @Future(callout=true)
    private static void sendSlackSummaryAsync(String channelId, Integer count, String subject) {
        String text = ':mega: 一括通知を送信しました\n'
            + '件名: ' + subject + '\n'
            + '送信件数: ' + count + ' 件';
        SlackIntegrationService.sendMessage(channelId, text);
    }

    // ----------------------------------------------------------------
    // Inner classes
    // ----------------------------------------------------------------

    public class PreviewItem {
        @AuraEnabled public String recipientName;
        @AuraEnabled public String recipientEmail;
        @AuraEnabled public String subject;
        @AuraEnabled public String body;
    }

    public class NotificationResult {
        @AuraEnabled public Integer successCount;
        @AuraEnabled public Integer failCount;
        @AuraEnabled public List<String> errors;
    }
}
