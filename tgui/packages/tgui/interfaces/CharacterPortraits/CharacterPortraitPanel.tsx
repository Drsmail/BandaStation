import type { ReactNode } from 'react';
import {
  Box,
  Button,
  LabeledList,
  NoticeBox,
  Section,
  Stack,
  Table,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { Window } from '../../layouts';

export type PortraitStatus = 'pending' | 'approved' | 'rejected' | 'deleted';

export type Portrait = {
  key: string;
  filename: string;
  uploader_ckey: string;
  status: PortraitStatus;
  reviewer_ckey?: string | null;
};

export type PortraitPanelData = {
  images: Portrait[];
  selected_image_key: string | null;
  selected_image_data: string | null;
  list_state: 'idle' | 'loading' | 'loaded' | 'unavailable';
  status_message: string;
  status_is_error: BooleanLike;
  service_configured: BooleanLike;
  busy: BooleanLike;
  processor_available: BooleanLike;
};

const statusPresentation: Record<
  PortraitStatus,
  { color: string; label: string }
> = {
  pending: { color: 'average', label: 'На модерации' },
  approved: { color: 'good', label: 'Одобрено' },
  rejected: { color: 'bad', label: 'Отклонено' },
  deleted: { color: 'label', label: 'Удалено' },
};

type Props = {
  children: ReactNode;
  data: PortraitPanelData;
  listTitle: string;
  onRefresh: () => void;
  onSelect: (key: string) => void;
  showModerationDetails?: boolean;
  title: string;
};

export const CharacterPortraitPanel = (props: Props) => {
  const {
    children,
    data,
    listTitle,
    onRefresh,
    onSelect,
    showModerationDetails = false,
    title,
  } = props;
  const {
    images,
    selected_image_key,
    selected_image_data,
    list_state,
    status_message,
    status_is_error,
    service_configured,
  } = data;
  const selectedPortrait =
    images.find((portrait) => portrait.key === selected_image_key) ?? null;

  return (
    <Window title={title} width={1100} height={650}>
      <Window.Content scrollable>
        <Stack fill style={{ minHeight: '560px' }}>
          <Stack.Item basis="42%">
            <Stack fill vertical>
              <Stack.Item grow>
                <Section title="Предпросмотр" fill>
                  <Stack fill vertical>
                    <Stack.Item grow>
                      <Box
                        height="280px"
                        style={{
                          alignItems: 'center',
                          backgroundColor: 'rgba(0, 0, 0, 0.35)',
                          border: '1px solid rgba(255, 255, 255, 0.12)',
                          display: 'flex',
                          justifyContent: 'center',
                          overflow: 'hidden',
                          position: 'relative',
                        }}
                      >
                        {selected_image_data ? (
                          <img
                            alt={selectedPortrait?.filename}
                            src={`data:image/png;base64,${selected_image_data}`}
                            style={{
                              position: 'absolute',
                              inset: 0,
                              height: '100%',
                              width: '100%',
                              objectFit: 'contain',
                            }}
                          />
                        ) : (
                          <Box color="label" italic textAlign="center">
                            {selectedPortrait
                              ? 'Для этого изображения нет доступного предпросмотра.'
                              : 'Выберите изображение в списке.'}
                          </Box>
                        )}
                      </Box>
                    </Stack.Item>
                    <Stack.Item mt={1}>
                      <LabeledList>
                        <LabeledList.Item label="Файл">
                          {selectedPortrait?.filename ?? '—'}
                        </LabeledList.Item>
                        {showModerationDetails && (
                          <LabeledList.Item label="Загрузил">
                            {selectedPortrait?.uploader_ckey ?? '—'}
                          </LabeledList.Item>
                        )}
                        <LabeledList.Item
                          color={
                            selectedPortrait
                              ? statusPresentation[selectedPortrait.status]
                                  .color
                              : undefined
                          }
                          label="Статус"
                        >
                          {selectedPortrait
                            ? statusPresentation[selectedPortrait.status].label
                            : '—'}
                        </LabeledList.Item>
                        {showModerationDetails && (
                          <LabeledList.Item label="Модератор">
                            {selectedPortrait?.reviewer_ckey ?? '—'}
                          </LabeledList.Item>
                        )}
                      </LabeledList>
                    </Stack.Item>
                  </Stack>
                </Section>
              </Stack.Item>
              <Stack.Item mt={1}>
                {!service_configured && (
                  <NoticeBox danger>
                    База данных портретов недоступна.
                  </NoticeBox>
                )}
                {!!status_message && (
                  <NoticeBox danger={!!status_is_error}>
                    {status_message}
                  </NoticeBox>
                )}
                {children}
              </Stack.Item>
            </Stack>
          </Stack.Item>

          <Stack.Item grow>
            <Section
              fill
              scrollable
              title={listTitle}
              buttons={
                <Button
                  disabled={list_state === 'loading' || !service_configured}
                  icon="sync"
                  onClick={onRefresh}
                >
                  Обновить
                </Button>
              }
            >
              {list_state === 'loading' && (
                <NoticeBox>Загрузка списка...</NoticeBox>
              )}
              {list_state === 'unavailable' && (
                <NoticeBox danger>Список изображений недоступен.</NoticeBox>
              )}
              {list_state === 'loaded' && images.length === 0 && (
                <NoticeBox>Загруженных изображений пока нет.</NoticeBox>
              )}
              {!!images.length && (
                <Table>
                  <Table.Row header>
                    <Table.Cell>Файл</Table.Cell>
                    {showModerationDetails && <Table.Cell>Загрузил</Table.Cell>}
                    <Table.Cell pr={2} textAlign="right">
                      Статус
                    </Table.Cell>
                  </Table.Row>
                  {images.map((portrait) => {
                    const selected = portrait.key === selected_image_key;
                    const presentation = statusPresentation[portrait.status];
                    return (
                      <Table.Row
                        key={portrait.key}
                        backgroundColor={
                          selected ? 'rgba(0, 100, 180, 0.35)' : 'transparent'
                        }
                      >
                        <Table.Cell>
                          <Button
                            color={selected ? 'blue' : 'transparent'}
                            fluid
                            onClick={() => onSelect(portrait.key)}
                          >
                            {portrait.filename}
                          </Button>
                        </Table.Cell>
                        {showModerationDetails && (
                          <Table.Cell>{portrait.uploader_ckey}</Table.Cell>
                        )}
                        <Table.Cell
                          color={presentation.color}
                          pr={2}
                          textAlign="right"
                        >
                          {presentation.label}
                        </Table.Cell>
                      </Table.Row>
                    );
                  })}
                </Table>
              )}
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
