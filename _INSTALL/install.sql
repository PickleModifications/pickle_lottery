CREATE TABLE IF NOT EXISTS `lottery_keno` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `numbers` longtext DEFAULT NULL,
  `receipts` longtext DEFAULT NULL,
  `date` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
);

CREATE TABLE IF NOT EXISTS `lottery_moneyball` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `numbers` longtext DEFAULT NULL,
  `receipts` longtext DEFAULT NULL,
  `date` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`) USING BTREE
);

CREATE TABLE IF NOT EXISTS `lottery_receipts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(50) DEFAULT NULL,
  `data` longtext DEFAULT NULL,
  `date` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`) USING BTREE
);