import { Button, Stack } from 'tgui-core/components';

import { useBackend } from '../backend';
import {
  CharacterPortraitPanel,
  type PortraitPanelData,
} from './CharacterPortraits/CharacterPortraitPanel';

export const CharacterPortraitModeration = () => {
  const { act, data } = useBackend<PortraitPanelData>();
  const selectedPortrait =
    data.images.find((portrait) => portrait.key === data.selected_image_key) ??
    null;
  const mayModerate = selectedPortrait?.status === 'pending' && !data.busy;

  return (
    <CharacterPortraitPanel
      data={data}
      listTitle="Все изображения"
      onRefresh={() => act('refresh')}
      onSelect={(key) => act('select', { key })}
      showModerationDetails
      title="Модерация портретов"
    >
      <Stack>
        <Stack.Item grow>
          <Button
            fluid
            color="good"
            disabled={!mayModerate}
            icon="check"
            onClick={() => act('approve')}
          >
            Одобрить
          </Button>
        </Stack.Item>
        <Stack.Item grow>
          <Button
            fluid
            color="bad"
            disabled={!mayModerate}
            icon="times"
            onClick={() => act('reject')}
          >
            Отклонить
          </Button>
        </Stack.Item>
      </Stack>
    </CharacterPortraitPanel>
  );
};
