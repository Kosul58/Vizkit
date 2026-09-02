--liquibase formatted sql logicalFilePath:delete_analytical_charts.sql

--changeset deepankar.sharma:delete-seeded-analytical-charts

--comment Delete commands for all analytical seed charts per sql seed file

DELETE FROM vizkit.chart
WHERE
    id IN (
        '77fb14df-6b12-4410-a54a-4225f1953790', -- Business Performance KPIs
        'f7b7070e-9dff-408b-b882-ee53fb22359c', -- Revenue & Sales Trend
        '96f2558c-40ab-400c-8f3c-692c8f3bfd7f', -- Revenue by Category
        '56a463a9-99ca-4c5c-a186-cad73dd60df9', -- Stock Status Mix
        'c449c454-e9b6-41a0-8081-85360d32df5e' -- Top Products Performance
    );

-- Delete charts seeded by 20260723001_analytical_executive_store_health_data.sql (21 charts)
DELETE FROM chart
WHERE
    id IN (
        '019fff82-e31a-79f2-bf5a-2d2fb3884362',
        '019fff82-e31a-722c-8303-27002345bfd8',
        '019fff82-e31a-737a-a3b9-abbc1fbe6cf8',
        '019fff82-e31a-7ab8-9ab6-182f18146294',
        '019fff82-e31a-7689-b215-209e686ffcc3',
        '019fff82-e31a-7d3c-8819-c9c6b13b5e8d',
        '019fff82-e31a-7430-9b0d-7d07b54cf0a2',
        '019fff82-e31a-7f7d-b294-6e3cc8e3a7a7',
        '019fff82-e31a-7d0f-a3ed-86fca428844f',
        '019fff82-e31a-74eb-9293-d7aa7f1356da',
        '019fff82-e31a-7323-8269-e6d293ea4b07',
        '019fff82-e31a-71ad-8841-83e7ba0a2123',
        '019fff82-e31a-7561-962f-82900d935653',
        '019fff82-e31a-7fd2-98bd-1d94abe28a36',
        '019fff82-e31a-7553-af0b-2fc2d407e2cb',
        '019fff82-e31a-7a80-b020-11c6d77f5502',
        '019fff82-e31a-7851-94f1-b2ed33f54156',
        '019fff82-e31a-7d26-8130-686674870f58',
        '019fff82-e31a-7585-80ff-4990966674d4',
        '019fff82-e31a-7ef0-9306-64b7d8c6b62d',
        '019fff82-e31a-788a-bb59-14e0199ea6b0'
    );

-- Delete charts seeded by 20260729001_analytical_order_line_item_analytics_data.sql (26 charts)
DELETE FROM chart
WHERE
    id IN (
        '019fff82-e31b-719e-9ef4-3c9253becb87',
        '019fff82-e31b-723e-9094-490488aabe62',
        '019fff82-e31b-7324-a5ca-7bc57b9bc509',
        '019fff82-e31b-753d-8e10-ec059dcda45d',
        '019fff82-e31b-7e27-9197-0666f3b361fd',
        '019fff82-e31b-7a36-b194-45c103600439',
        '019fff82-e31b-7e1a-8714-74c60f69072e',
        '019fff82-e31b-7c5d-ae47-dd60a34e7dc7',
        '019fff82-e31b-702b-8871-b4a7b41f48ed',
        '019fff82-e31b-7369-bc64-833156976630',
        '019fff82-e31b-7ea2-96e7-94369d8d22a0',
        '019fff82-e31b-786f-9d94-810596bff3e8',
        '019fff82-e31b-7c4f-b65d-bdeb64328a28',
        '019fff82-e31b-7505-ba36-3c1dd912477f',
        '019fff82-e31b-77da-849c-4dcfb1d0ab6f',
        '019fff82-e31b-70e4-8f9e-3c0c9472932d',
        '019fff82-e31b-7bfb-ae14-6b2e4c98ee78',
        '019fff82-e31b-7e59-932d-1541b1ecf67e',
        '019fff82-e31b-7a43-a257-44955fedfa5b',
        '019fff82-e31b-7d85-9cd5-abac703c0eab',
        '019fff82-e31b-7046-ab17-44ababdc75de',
        '019fff82-e31b-7db6-9794-777cfa9aefdc',
        '019fff82-e31b-793a-8fcc-6877cfc039bf',
        '019fff82-e31b-7e3a-a503-265f777d3aa1',
        '019fff82-e31b-7b9d-b376-960a16cbf47a',
        '019fff82-e31b-76e0-bf62-575b5d09b4da'
    );

-- Delete charts seeded by 20260730001_analytical_refunds_and_reversals_data.sql (26 charts)
DELETE FROM chart
WHERE
    id IN (
        '019fff82-e31b-7b01-ac42-94e645ff7ab3',
        '019fff82-e31b-748a-8425-3bb474a85b65',
        '019fff82-e31b-74ba-ba74-370b43f625be',
        '019fff82-e31b-79f4-9202-7fba04cbf8de',
        '019fff82-e31b-75ee-96c8-10a77eeb0a92',
        '019fff82-e31b-7388-b15e-8f691b1e7b67',
        '019fff82-e31b-78d0-9da5-5953fef1cb38',
        '019fff82-e31b-7dbf-9fe8-864fac6fd708',
        '019fff82-e31b-7fdf-83ea-fda8faadf542',
        '019fff82-e31b-7b00-ac1b-c9fc8f9cd155',
        '019fff82-e31b-713f-b4fc-231044934ca5',
        '019fff82-e31b-7080-85bc-6e2dd340d5e1',
        '019fff82-e31b-7f26-b6d9-e5be106a2e02',
        '019fff82-e31b-72dd-a2be-2d371f692040',
        '019fff82-e31b-750a-ac69-e152e35ac365',
        '019fff82-e31b-7510-b989-6f45dce0489f',
        '019fff82-e31b-7f43-a957-21278090eb7f',
        '019fff82-e31b-7cc9-b447-68099ff903d1',
        '019fff82-e31b-71ac-8d79-6ab5ac8211ba',
        '019fff82-e31b-78da-a0cf-ee6e0c231283',
        '019fff82-e31b-71db-8c0a-0fa0605c12d0',
        '019fff82-e31b-7458-8319-42a3cd185f85',
        '019fff82-e31b-7846-9d18-045c5f46bef8',
        '019fff82-e31d-7e78-99f7-d8efbb717b07',
        '019fff82-e31d-78ee-b15c-582a98b59a1f',
        '019fff82-e31d-71d9-8086-eb0e7405032c'
    );

-- Delete charts seeded by 20260731001_order_report_data.sql (21 charts)
DELETE FROM chart
WHERE
    id IN (
        '019fff82-e31d-7a2c-9710-92ecf736d574',
        '019fff82-e31d-73b8-9e6d-85c6d409913c',
        '019fff82-e31d-797f-be67-74f6653427aa',
        '019fff82-e31d-7f37-bca1-e5405982d060',
        '019fff82-e31d-7bf1-8c13-df22e4af91f2',
        '019fff82-e31d-7bc3-a07b-7beb0c45249b',
        '019fff82-e31d-769a-bc42-f99a7173de6a',
        '019fff82-e31d-7345-8f03-4bdb44f89b93',
        '019fff82-e31d-7da5-bec3-40a9b99a9baa',
        '019fff82-e31d-7d01-b0e7-e98182e66062',
        '019fff82-e31d-7950-8048-cc15a851e0f2',
        '019fff82-e31d-7a4d-96d2-1b2921c3001d',
        '019fff82-e31d-7c28-8dee-e197d859bba8',
        '019fff82-e31d-7adf-9ec0-da4952b71ce1',
        '019fff82-e31d-772e-a943-97b7591e0ecd',
        '019fff82-e31d-7e39-a770-59ebdce216a3',
        '019fff82-e31d-7cbb-9e99-db4ae79df001',
        '019fff82-e31d-7383-af37-68c2c40c388b',
        '019fff82-e31d-7247-92b0-22f212b5136c',
        '019fff82-e31d-7eca-b184-91c61334d67c',
        '019fff82-e31d-78eb-98ea-48b41df26c99'
    );

-- Delete charts seeded by 20260804001_analytical_product_and_inventory_health_data.sql (29 charts)
DELETE FROM chart
WHERE
    id IN (
        '019fff82-e31e-7982-a4ad-54e5b0b51284',
        '019fff82-e31e-7a30-9953-eb452bce7b85',
        '019fff82-e31e-7494-b147-e0825a13ad10',
        '019fff82-e31e-7a80-87d7-b73688031a3c',
        '019fff82-e31e-7c6d-8384-a1140a90563f',
        '019fff82-e31e-7ada-8e58-b9818b23a2bc',
        '019fff82-e31e-72ff-b56a-7858f69bc0bf',
        '019fff82-e31e-7fec-a16b-dd174e41fe83',
        '019fff82-e31e-7c77-934f-8e50724277f0',
        '019fff82-e31e-7a3e-859a-6ba09f321cc8',
        '019fff82-e31e-7fbe-8a1d-8005aaea2a53',
        '019fff82-e31e-748e-b205-28aafe15d0e8',
        '019fff82-e31e-744a-b513-00f6ebae2e7e',
        '019fff82-e31e-78ef-874d-087573437963',
        '019fff82-e31e-742f-b74d-ffe5fc4f9a83',
        '019fff82-e31e-7dd0-8698-7e4c4a02a4c7',
        '019fff82-e31e-71c6-b90c-0940ff0790c1',
        '019fff82-e31e-76cf-8717-df6af72da7c4',
        '019fff82-e31e-7ab0-8fde-619cbe1d3f63',
        '019fff82-e31e-7bfd-a6b5-2777df9b07ba',
        '019fff82-e31e-766d-bf1f-31a4dc974d0b',
        '019fff82-e31e-741a-9b77-036f24795d55',
        '019fff82-e31e-7b01-8e90-b7e72ea47d3d',
        '019fff82-e31e-7f12-862d-2a71d90c903a',
        '019fff82-e31e-7444-b17e-549809be2b6b',
        '019fff82-e31e-752c-8bf6-3c3f866777c0',
        '019fff82-e31e-7603-b866-cadd19d65482',
        '019fff82-e31e-706d-838e-ee315b8dde04',
        '019fff82-e31e-7e68-8f78-8a4b440e0b84'
    );

-- Delete charts seeded by 20260812001_analytical_customer_retention.sql (27 charts)
DELETE FROM chart
WHERE
    id IN (
        '019fff9a-1dfa-7ef3-8402-c7e413fe686d',
        '019fff9a-1dfa-7282-8db8-0ad49fdec2cc',
        '019fff9a-1dfb-7513-8ee7-49b421c93f16',
        '019fff9a-1dfb-727b-b29d-9f6592bc4660',
        '019fff9a-1dfb-7807-bf9d-7db4e9fb7900',
        '019fff9a-1dfb-7067-a154-101db904ec65',
        '019fff9a-1dfb-76a0-844c-85dcf1a54191',
        '019fff9a-1dfb-7d54-ae3f-df0d8febed39',
        '019fff9a-1dfb-7047-bd5e-e1400ef79384',
        '019fff9a-1dfb-718e-b555-8d50bbaff35c',
        '019fff9a-1dfb-76bb-bfd3-3eee427a2d97',
        '019fff9a-1dfb-756f-bf31-02577fcf2164',
        '019fff9a-1dfb-70e1-9bb5-d0221b4e1569',
        '019fff9a-1dfb-7501-93db-3e10a209f815',
        '019fff9a-1dfb-7d94-805d-a1062b8c8565',
        '019fff9a-1dfb-7980-9aef-d4218448b532',
        '019fff9a-1dfb-702e-87f5-5d558c3b3a79',
        '019fff9a-1dfb-71fd-9571-3b8eee00748e',
        '019fff9a-1dfb-7d51-aba5-9eac6880bcee',
        '019fff9a-1dfb-7501-9628-e35284463dde',
        '019fff9a-1dfb-73e3-b8cb-cf8d48dde497',
        '019fff9a-1dfb-71d9-baa2-c69257c65184',
        '019fff9a-1dfb-74e4-ac8d-73f6dc14ac98',
        '019fff9a-1dfb-7bca-8834-63524c92900d',
        '019fff9a-1dfb-7e71-837c-54bae0ae10c2',
        '019fff9a-1dfb-7814-b98f-0bdf98266f9a',
        '019fff9a-1dfb-7217-b231-2c8856fc75a5'
    );

-- Delete charts seeded by 20260812002_analytical_sales_channel_attribution.sql (29 charts)
DELETE FROM chart
WHERE
    id IN (
        '019fffa2-0f80-7a28-bd46-3540650afb5d',
        '019fffa2-0f80-77ca-b168-dec3d25e1385',
        '019fffa2-0f80-75e3-b775-87a0a8633e24',
        '019fffa2-0f80-7d9e-8291-cc8dd6928cfd',
        '019fffa2-0f80-777c-ae56-782c587a8bde',
        '019fffa2-0f80-7889-9761-5bc951290334',
        '019fffa2-0f80-7a6c-a7fa-d1b9b8e71fd8',
        '019fffa2-0f80-7819-9ed6-49cfe9e1ccfc',
        '019fffa2-0f80-77bd-8a78-95f23c54470b',
        '019fffa2-0f80-75b9-ab4b-b31d2a23ed61',
        '019fffa2-0f80-70c4-9a28-0385c2cf3627',
        '019fffa2-0f80-776e-972e-acecde275b53',
        '019fffa2-0f80-7da9-bd88-43e4b7c25702',
        '019fffa2-0f80-770e-8d37-2f7fa9a51a10',
        '019fffa2-0f80-7d69-850d-7e635d094b1d',
        '019fffa2-0f80-70ef-9a0f-c359403e905d',
        '019fffa2-0f80-71ce-a2f8-1d91eb3cf4e6',
        '019fffa2-0f80-73f6-a81c-b324e3603939',
        '019fffa2-0f80-79ee-84eb-b644d7b1d5c4',
        '019fffa2-0f80-7510-8c97-1bd21c12e627',
        '019fffa2-0f80-71e2-b91c-c916a676dd3e',
        '019fffa2-0f80-7305-bd5d-53ae0ca111f1',
        '019fffa2-0f80-7aec-b21a-cf83cf3fd204',
        '019fffa2-0f80-77e4-8127-7707ab16f3d5',
        '019fffa2-0f80-7c9f-a6df-cc1624af3cd2',
        '019fffa2-0f80-787c-ab20-d084e6171e29',
        '019fffa2-0f80-763a-b2bb-f4448a711028',
        '019fffa2-0f80-7234-9907-dd1623f04383',
        '019fffa2-0f80-7abe-96ab-bc331790de2d'
    );

-- Delete charts seeded by 20260813001_analytical_payments_and_transactions.sql (29 charts)
DELETE FROM chart
WHERE
    id IN (
        '019fffa3-ddd3-7369-b2f8-35100851f1f5',
        '019fffa3-ddd3-72e3-a14e-782dfd330b5b',
        '019fffa3-ddd3-7b3c-9f95-309dbdb57dfe',
        '019fffa3-ddd3-752f-9af4-6c1f2cb046f1',
        '019fffa3-ddd3-7057-8f69-3814f3324a8e',
        '019fffa3-ddd3-74f4-8b88-84aa1bf30d42',
        '019fffa3-ddd3-7a0f-9e52-a5fff7b2b20f',
        '019fffa3-ddd3-7597-a973-629f58d62294',
        '019fffa3-ddd3-7325-ae53-eba74722bea6',
        '019fffa3-ddd3-7684-970a-205ebbac5a02',
        '019fffa3-ddd3-795f-a999-4897d4e273db',
        '019fffa3-ddd3-73c3-a7d0-1e7c6562c512',
        '019fffa3-ddd3-7be5-89dc-101e463d6bb3',
        '019fffa3-ddd3-72af-89f6-f1ea24b39173',
        '019fffa3-ddd3-7db7-8dbd-baf76c474af1',
        '019fffa3-ddd3-726f-b9ab-c57314c5f5e1',
        '019fffa3-ddd3-7cbb-9fbc-b0387524b1f4',
        '019fffa3-ddd3-7bfd-8994-043808a9ede2',
        '019fffa3-ddd3-7db2-8979-6ceed49ee742',
        '019fffa3-ddd3-72e7-921a-5c061dedb213',
        '019fffa3-ddd3-7fa3-835b-cd566678e1df',
        '019fffa3-ddd3-7fcb-9184-cba9c41c659c',
        '019fffa3-ddd3-7ac0-84ad-a47393da0230',
        '019fffa3-ddd3-79b5-978e-90241244259a',
        '019fffa3-ddd3-70da-a2b4-ba575ac4d820',
        '019fffa3-ddd3-7803-b1ad-78780dcea258',
        '019fffa3-ddd3-7b1a-a7b4-6d3cc0d9d8b7',
        '019fffa3-ddd3-7964-b52a-a330c2f1e7a0',
        '019fffa3-ddd3-7ca6-a8ff-5976abc98ff7'
    );

-- Delete charts seeded by 20260813002_analytical_payout_reconciliation.sql (20 charts)
DELETE FROM chart
WHERE
    id IN (
        '019fff9a-1dfb-7643-89c7-d7678e8f85c5',
        '019fff9a-1dfb-7481-910e-164bd1290509',
        '019fff9a-1dfb-7269-bc06-14bf85bc646f',
        '019fff9a-1dfb-70ad-996d-78ab00757ba4',
        '019fff9a-1dfb-74f8-b5c2-795540de6cc4',
        '019fff9a-1dfb-78aa-8ac2-442b6ae4fa00',
        '019fff9a-1dfc-7225-8d84-2ae86619f5f5',
        '019fff9a-1dfc-77a3-8d1a-a4887bcef27b',
        '019fff9a-1dfc-76f3-8163-d7baf58ee1e0',
        '019fff9a-1dfc-7491-a05d-a584bd3271b1',
        '019fff9a-1dfc-77ec-abb8-2aab644b187f',
        '019fff9a-1dfc-73b0-a502-e293c8b94ad0',
        '019fff9a-1dfc-7179-ae0a-3ac7990f5b2a',
        '019fff9a-1dfc-7310-b39b-5a6d231ece08',
        '019fff9a-1dfc-728c-a681-6012316bb4b3',
        '019fff9a-1dfc-7e73-822c-0da1b7310056',
        '019fff9a-1dfc-7c1a-b97b-defba885c683',
        '019fff9a-1dfc-7386-b8d7-02ff5dbaebd7',
        '019fff9a-1dfc-7296-a2a1-dadff4e157b8',
        '019fff9a-1dfc-7c7d-86e5-234577d4f2ae'
    );

-- Delete charts seeded by 20260814001_analytical_inventory_location.sql (28 charts)
DELETE FROM chart
WHERE
    id IN (
        '019fff9a-1dfc-7913-b680-280fa241f5c5',
        '019fff9a-1dfc-7221-83be-9ef1db174eef',
        '019fff9a-1dfc-7a67-a13a-f4be3232af49',
        '019fff9a-1dfc-7f1c-8633-d54b46a9f55e',
        '019fff9a-1dfc-7fe3-864f-63a5e46aba11',
        '019fff9a-1dfc-78bc-b6ad-abdbad79f1e3',
        '019fff9a-1dfc-79fc-9640-ef363d7491af',
        '019fff9a-1dfc-77e4-91ed-7ffbb2ad68bb',
        '019fff9a-1dfc-723b-8e67-79ec0caf69e6',
        '019fff9a-1dfc-771c-a028-9b840c9feeec',
        '019fff9a-1dfc-7cb8-9c5e-132d1a372cbe',
        '019fff9a-1dfc-7902-8a87-fca49495f135',
        '019fff9a-1dfc-7c07-a554-8e4ab001e903',
        '019fff9a-1dfc-7c2d-beb8-ea50708414ee',
        '019fff9a-1dfc-7b18-90b7-5eaf4d0062d7',
        '019fff9a-1dfc-7fc3-8116-62b95b12534e',
        '019fff9a-1dfd-7d7d-8b21-45a9066a365d',
        '019fff9a-1dfd-7e79-83d1-5b9094a2b62e',
        '019fff9a-1dfd-7a0e-baaf-247a79f97951',
        '019fff9a-1dfd-79fc-a01e-4d8faeede3a4',
        '019fff9a-1dfd-73f8-99c8-cf67c8421b51',
        '019fff9a-1dfd-76e4-99d4-5168b37fb95f',
        '019fff9a-1dfd-73b5-a621-555bfce3e3ec',
        '019fff9a-1dfd-786b-996d-22cc13375928',
        '019fff9a-1dfd-7dde-b41a-49261098371d',
        '019fff9a-1dfd-72e6-b151-76e45937aba1',
        '019fff9a-1dfd-76d4-9608-da40ce2f7995',
        '019fff9a-1dfd-74e2-b5f8-3f1a07395cb2'
    );

-- 1. Leaf / Dependent transactions & child tables
DELETE FROM gift_card_transaction;

DELETE FROM gift_card;

DELETE FROM dispute;

DELETE FROM tender_transaction;

DELETE FROM transaction;

DELETE FROM refund;

DELETE FROM order_line_item;

-- 2. Orders fact table
DELETE FROM orders;

-- 3. Inventory & Point of Sale dependent tables
DELETE FROM pos_device;

DELETE FROM cash_drawer;

DELETE FROM collection_product;

DELETE FROM inventory_level;

-- 4. Inventory items & locations
DELETE FROM inventory_item;

DELETE FROM inventory_location;

-- 5. Products, variants, collections & taxonomy
DELETE FROM product_variant;

DELETE FROM product;

DELETE FROM collection;

DELETE FROM taxonomy_category;

-- 6. Channels, customers & addresses
DELETE FROM channel;

DELETE FROM sh_customer_address;

DELETE FROM sh_customer;

DELETE FROM sh_address;

-- 7. Base dimension tables & payouts
DELETE FROM store_staff;

DELETE FROM order_app;

DELETE FROM payout;