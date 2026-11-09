CREATE TABLE `character_portraits` (
  `id` char(36) NOT NULL,
  `uploader_ckey` varchar(32) NOT NULL,
  `filename` varchar(255) NOT NULL,
  `status` enum('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  `width` smallint unsigned NOT NULL,
  `height` smallint unsigned NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `reviewer_ckey` varchar(32) DEFAULT NULL,
  `reviewed_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `owner_status` (`uploader_ckey`, `status`),
  KEY `status_created` (`status`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `character_portrait_selections` (
  `ckey` varchar(32) NOT NULL,
  `character_slot` smallint unsigned NOT NULL,
  `portrait_id` char(36) NOT NULL,
  PRIMARY KEY (`ckey`, `character_slot`),
  KEY `portrait_id` (`portrait_id`),
  CONSTRAINT `portrait_selection_image` FOREIGN KEY (`portrait_id`) REFERENCES `character_portraits` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
INSERT INTO `schema_revision_220` (`major`, `minor`) VALUES (1, 4);
