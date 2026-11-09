import { Box, Section, Stack } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';
import { CharacterPreview } from './common/CharacterPreview';

type Data = {
  character_name: string;
  obscured: BooleanLike;
  assigned_map: string;
  flavor_text: string;
  portrait_url?: string | null;
};

export const ExaminePanel = (props) => {
  const { data } = useBackend<Data>();
  const { character_name, obscured, assigned_map, flavor_text, portrait_url } =
    data;
  return (
    <Window title="Подробное описание" width={600} height={350} theme="ntos">
      <Window.Content>
        <Stack fill>
          <Stack.Item basis="40%" style={{ minWidth: 0 }}>
            <Section
              fill
              title={portrait_url ? 'Портрет персонажа' : 'Превью персонажа'}
            >
              {!obscured &&
                (portrait_url ? (
                  <Box
                    height="100%"
                    style={{ position: 'relative', overflow: 'hidden' }}
                  >
                    <img
                      alt="Портрет персонажа"
                      src={portrait_url}
                      style={{
                        position: 'absolute',
                        inset: 0,
                        width: '100%',
                        height: '100%',
                        objectFit: 'contain',
                      }}
                    />
                  </Box>
                ) : (
                  <CharacterPreview id={assigned_map} height="100%" />
                ))}
            </Section>
          </Stack.Item>
          <Stack.Item grow>
            <Stack fill vertical>
              <Stack.Item grow>
                <Section scrollable fill title={`${character_name}, описание:`}>
                  <Box
                    style={{
                      whiteSpace: 'pre-wrap',
                      wordBreak: 'break-word',
                      overflowWrap: 'break-word',
                    }}
                  >
                    {flavor_text}
                  </Box>
                </Section>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
