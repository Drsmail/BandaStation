import { useState } from 'react';
import { Box, Button, NoticeBox, Stack } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import {
  CharacterPortraitPanel,
  type PortraitPanelData,
} from './CharacterPortraits/CharacterPortraitPanel';

type Data = PortraitPanelData & {
  upload_in_progress: BooleanLike;
  active_portrait_id: string | null;
};

export const CharacterPortraits = () => {
  const { act, data } = useBackend<Data>();
  const [showRequirements, setShowRequirements] = useState(false);

  return (
    <CharacterPortraitPanel
      data={data}
      listTitle="Мои изображения"
      onRefresh={() => act('refresh')}
      onSelect={(key) => act('select', { key })}
      title="Портреты персонажей"
    >
      {showRequirements && (
        <NoticeBox>
          <Box>Требования к изображению:</Box>
          <ul style={{ margin: 0, paddingLeft: '1.5em' }}>
            <li>PNG, JPEG или WebP до 10 МиБ;</li>
            <li>
              до 24 миллионов пикселей; большая сторона уменьшается до 1080 px;
            </li>
            <li>не более 10 изображений в ожидании модерации;</li>
            <li>
              изображение сохраняется в PNG; доступны только одобренные
              портреты.
            </li>
          </ul>
        </NoticeBox>
      )}
      <Stack mb={1}>
        <Stack.Item grow>
          <Button
            fluid
            disabled={
              !!data.busy ||
              data.images.find((image) => image.key === data.selected_image_key)
                ?.status !== 'approved'
            }
            selected={
              !!data.active_portrait_id &&
              data.active_portrait_id === data.selected_image_key
            }
            onClick={() => act('use')}
          >
            Выбрать
          </Button>
        </Stack.Item>
        <Stack.Item>
          <Button
            disabled={!!data.busy || !data.active_portrait_id}
            onClick={() => act('clear')}
          >
            Убрать портрет
          </Button>
        </Stack.Item>
      </Stack>
      {!data.processor_available && (
        <NoticeBox danger>
          Для загрузки установите библиотеку portrait_processor на сервере.
        </NoticeBox>
      )}
      <Stack>
        <Stack.Item grow>
          <Button
            fluid
            color="good"
            disabled={
              !data.service_configured ||
              !data.processor_available ||
              !!data.upload_in_progress ||
              !!data.busy
            }
            icon="upload"
            onClick={() => act('upload')}
          >
            {data.upload_in_progress ? 'Загрузка...' : 'Загрузить файл'}
          </Button>
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="info-circle"
            selected={showRequirements}
            onClick={() => setShowRequirements(!showRequirements)}
          >
            Info
          </Button>
        </Stack.Item>
      </Stack>
    </CharacterPortraitPanel>
  );
};
