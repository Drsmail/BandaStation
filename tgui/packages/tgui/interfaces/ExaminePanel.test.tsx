import { afterEach, describe, expect, it } from 'bun:test';
import { act, cleanup, render, screen } from '@testing-library/react';
import { gameDataAtom, store } from '../events/store';
import { ExaminePanel } from './ExaminePanel';

afterEach(cleanup);

const setDescription = (portrait_url: string | null, obscured = false) => {
  store.set(gameDataAtom, {
    character_name: 'Test Character',
    flavor_text: 'Описание персонажа',
    assigned_map: 'examine_test_map',
    portrait_url,
    obscured,
  });
};

describe('Examine panel portraits', () => {
  it('shows the portrait alongside the character description', () => {
    setDescription('portrait.png');
    act(() => render(<ExaminePanel />));
    expect(screen.getByAltText('Портрет персонажа').getAttribute('src')).toBe(
      'portrait.png',
    );
    expect(screen.getByText('Описание персонажа')).toBeDefined();
    expect(screen.queryByText('Превью персонажа')).toBeNull();
  });

  it('keeps the dynamic preview when no portrait is selected', () => {
    setDescription(null);
    act(() => render(<ExaminePanel />));
    expect(screen.getByText('Превью персонажа')).toBeDefined();
    expect(screen.queryByAltText('Портрет персонажа')).toBeNull();
  });

  it('hides the portrait when the face is obscured', () => {
    setDescription('portrait.png', true);
    act(() => render(<ExaminePanel />));
    expect(screen.queryByAltText('Портрет персонажа')).toBeNull();
  });
});
